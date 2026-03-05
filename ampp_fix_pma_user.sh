#!/usr/bin/env bash

#
# Fix PMA user issue - patch for macOS
# Last updated: 5th March 2026
# Copyright (c) 2026 Monash University
# Distributed under MIT license
#

set -euo pipefail

# ---------- Helpers ----------
cecho() { local c="$1"; shift; printf "%b%s%b\n" "$c" "$*" "\033[0m"; }
info()  { cecho "\033[36m" "ℹ︎ $*"; }
ok()    { cecho "\033[32m" "✔ $*"; }
warn()  { cecho "\033[33m" "⚠ $*"; }
alert()  { cecho "\033[30;43m" "⚠ $*"; }
bang()  { cecho "\033[37;41m" "⚠ $*"; }
err()   { cecho "\033[31m" "✘ $*" >&2; }

confirm() {
  local prompt="${1:-Proceed?}"
  local reply
  while true; do
    read -r -p "$prompt [y/N] " reply || true
    if [[ "$reply" =~ ^([Yy]([Ee][Ss])?|[Yy])$ ]]; then
      return 0
    elif [[ -z "$reply" || "$reply" =~ ^([Nn]([Oo])?|[Nn])$ ]]; then
      return 1
    else
      echo "Please type y or n."
    fi
  done
}

run_step() {
  # run_step "description" cmd...
  local desc="$1"; shift
  if confirm "$desc"; then
    if "$@"; then
      ok "$desc"
    else
      err "Failed: $desc"
      exit 1
    fi
  else
    warn "Skipped: $desc"
    return 2
  fi
}

brew_exists() { command -v brew >/dev/null 2>&1; }

is_installed() {
  # Check if a Homebrew formula is installed (any version)
  local formula="$1"
  brew list --formula --versions "$formula" >/dev/null 2>&1
}

stop_service_if_present() {
  local formula="$1"
  if brew services list 2>/dev/null | awk '{print $1}' | grep -qx "$formula"; then
    run_step "Stop service for $formula" brew services stop "$formula" || true
  fi
}

start_service() {
  local formula="$1"
  if confirm "Start $formula as a background service (launchd)?" ; then
    brew services start "$formula"
    ok "Started service: $formula"
  else
    warn "Service not started: $formula"
  fi
}

info "This script will fix a known issue with phpMyAdmin where 'User accounts' option is not available"
echo 
warn "Read on-screen information carefully as this script may make significant changes to your operating system."

echo -e "\n\n"
alert "If the script is not working as expected, open an issue at"
alert "https://github.com/ugie-cake/ampp/issues"
echo -e "\n\n"

# Fetch phpmyadmin config file
PMA_CFG="$HOMEBREW_PREFIX/etc/phpmyadmin.config.inc.php"

if confirm "Update phpMyAdmin configuration file in $PMA_CFG with proper configuration?"; then
  # Blowfish secret generation and get current username (used by Homebrew MariaDB)
  NEW_SECRET="$(openssl rand -base64 24 | tr -d '\n' | cut -c1-32)"
  # Fetch current username
  CURRENT_USER="$(id -un)"

  # Prepare the patch file
  cat >"/tmp/ieampp_pma_fix.patch" <<EOF
--- phpmyadmin.config.inc.php.original	2026-03-05 11:24:03
+++ phpmyadmin.config.inc.php.blowfish	2026-03-05 11:31:29
@@ -13,7 +13,7 @@
  * This is needed for cookie based authentication to encrypt the cookie.
  * Needs to be a 32-bytes long string of random bytes. See FAQ 2.10.
  */
-\$cfg['blowfish_secret'] = 'RgRis6hy1Ny+mGoktp/AxpGDAGq97DIE'; /* YOU MUST FILL IN THIS FOR COOKIE AUTH! */
+\$cfg['blowfish_secret'] = '$NEW_SECRET'; /* YOU MUST FILL IN THIS FOR COOKIE AUTH! */

 /**
  * Servers configuration
@@ -28,7 +28,7 @@
 \$cfg['Servers'][\$i]['auth_type'] = 'config';
 /* Server parameters */
 \$cfg['Servers'][\$i]['host'] = 'localhost';
-\$cfg['Servers'][\$i]['user'] = 'macosvm';
+\$cfg['Servers'][\$i]['user'] = '$CURRENT_USER';
 \$cfg['Servers'][\$i]['compress'] = false;
 \$cfg['Servers'][\$i]['AllowNoPassword'] = true;
EOF

  # Patch the pma config file
  if ! patch "$PMA_CFG" < /tmp/ieampp_pma_fix.patch; then
    echo "Patch $PMA_CFG failed; printing context and aborting."
    exit 1
  fi

  ok "phpMyAdmin configuration completed!"
else
  warn "Skipped: phpMyAdmin configuration update."
fi

ok "All done."

alert "Next steps:"
echo " - Open http://localhost:8080/phpmyadmin to verify phpMyAdmin has 'User accounts' option on the top navigation bar"