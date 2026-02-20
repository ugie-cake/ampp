#!/usr/bin/env bash

#
# Industry Experience Development Environment Setup Script for macOS
# Last updated: 20th February 2026
# Copyright (c) 2026 Monash University
# Distributed under MIT license
#
# Requiored environment:
# - Supported macOS versions (tested on macOS 26) with default zsh shell
# - Google Chrome (recommended web browser)
# - Homebrew package manager
#
# Installed packages: httpd, mariadb, php@8.4, composer, phpmyadmin
# Starts services: httpd, mariadb
#
# Sources:
# - Official Homebrew install command: https://brew.sh/
# - Homebrew package caveats
#

set -euo pipefail

# ---------- Helpers ----------
cecho() { local c="$1"; shift; printf "%b%s%b\n" "$c" "$*" "\033[0m"; }
info()  { cecho "\033[36m" "ℹ︎ $*"; }
ok()    { cecho "\033[32m" "✔ $*"; }
warn()  { cecho "\033[33m" "⚠ $*"; }
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

info "Welcome to Industry Experience Development Environment Setup Script for macOS!"
warn "Read on-screen information carefully as this script may make significant changes to your operating system."
warn "This script is for Apple Silicon Macs with the default zsh shell. If you're using an Intel Mac and/or bash, the script will halt and you should consult your studio mentors."

# ---------- CPU architecture check ----------
arch_name="$(uname -m)"
if [[ "$arch_name" != "arm64" ]]; then
  echo "✘ This script is intended for Apple Silicon (arm64) Macs only. Detected: $arch_name"
  echo "  Exiting without making changes."
  exit 1
fi
echo "✔ Apple Silicon (arm64) detected. Continuing..."

# ---------- Shell check ----------
if [[ -z "${SHELL:-}" || "${SHELL##*/}" != "zsh" ]]; then
  echo "✘ This script requires your login shell to be zsh. Detected SHELL: ${SHELL:-unset}"
  exit 1
fi

echo "✔ SHELL indicates zsh (${SHELL}). Continuing..."

# ---------- 0) Homebrew presence ----------
if ! brew_exists; then
  warn "Homebrew not found. It is required for this setup."
  info "The official installer from brew.sh will be used."
  warn "Homebrew installation requires 'sudo' access (you'll need to type in your account password once during the procedure), and this process can take quite a while depends on your Internet speed. "
  if confirm "Install Homebrew now?"; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ok "Homebrew installed. Initialising Homebrew in current terminal session..."
    if ! grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
        echo >> "$HOME/.zprofile"
        echo 'eval "$(/opt/homebrew/bin/brew shellenv zsh)"' >> "$HOME/.zprofile"
    fi
    # Initialize current shell environment
    test -r ~/.zprofile && eval "$(/opt/homebrew/bin/brew shellenv zsh)" || true
  else
    err "Homebrew is required. Aborting."
    exit 1
  fi
fi

HOMEBREW_PREFIX="$(brew --prefix)"
ok "Using Homebrew prefix: $HOMEBREW_PREFIX"

# ---------- 1) Brew update ----------
run_step "Update Homebrew and formulae (brew update)" brew update || true

# ---------- 2) Detect existing installs ----------
CANDIDATES=(httpd mysql mariadb php php@8.4 composer phpmyadmin)
FOUND=()
for f in "${CANDIDATES[@]}"; do
  if is_installed "$f"; then FOUND+=("$f"); fi
done

if ((${#FOUND[@]})); then
  warn "Detected installed packages: ${FOUND[*]}"
  warn "To continue this script, all packages listed above will need to be uninstalled first. "
  cat << EOS
Uninstalling may remove binaries, configs, and data directories under Homebrew.
This can include webroot, database data under $HOMEBREW_PREFIX/var/mysql,
and custom .conf files. All data that is not backed up will be lost!

EOS
  if confirm "Proceed to STOP services and UNINSTALL ALL of: httpd, mysql, mariadb, php, php@8.4, composer, phpmyadmin ?"; then
    # Stop and uninstall ALL targets regardless of which were found (per requirement)
    for svc in httpd mysql mariadb php php@8.4; do
      stop_service_if_present "$svc" || true
    done

    run_step "Uninstall Homebrew packages: composer phpmyadmin php php@8.4 httpd mysql mariadb" brew uninstall --force composer phpmyadmin php php@8.4 httpd mysql mariadb || true

    warn "Cleaning up data and configurations for uninstalled packages..."
    # Clean up Homebrew caches
    brew cleanup
    # Delete configuration files
    # httpd
    rm -rf $HOMEBREW_PREFIX/etc/httpd
    rm -rf $HOMEBREW_PREFIX/var/www
    # mysql and mariadb
    rm -rf $HOMEBREW_PREFIX/etc/my.cnf
    rm -rf $HOMEBREW_PREFIX/etc/my.cnf.d
    rm -rf $HOMEBREW_PREFIX/etc/my.cnf.default
    rm -rf $HOMEBREW_PREFIX/etc/mecabrc
    rm -rf $HOMEBREW_PREFIX/var/mysql
    # php@8.4
    rm -rf $HOMEBREW_PREFIX/etc/php/8.4
    # phpmyadmin
    rm -rf $HOMEBREW_PREFIX/etc/phpmyadmin.config.inc.php
  else
    warn "Uninstall step skipped at your request."
  fi
else
  ok "No existing target packages detected."
fi

# ---------- 3) Install required packages ----------
run_step "Install httpd php@8.4 mariadb composer phpmyadmin" brew install httpd php@8.4 mariadb composer phpmyadmin

# ---------- 4) Configure various components ----------
# Add PHP 8.4 to system path
if [[ -f "$HOME/.zshrc" ]]; then
    info "Here are the existing contents in your '.zshrc' file:"
    echo "------------------------------------------------"
    cat "$HOME/.zshrc"
    echo "------------------------------------------------"
else
    warn "No .zshrc file exists in your home directory."
    echo "This is normal if you never installed Homebrew before — the file will be created when needed."
fi
echo
info "Next is to add php@8.4 to system PATH. This will make PHP v8.4 as default PHP interpreter in your terminal."
echo "If you already see something like 'export PATH=/opt/homebrew/opt/php@8.4'"
echo "in your '.zshrc' file, you should select no. Otherwise, you should select yes. "
if confirm "Add php@8.4 to system PATH?"; then
  echo >> "$HOME/.zshrc"
  echo 'export PATH="/opt/homebrew/opt/php@8.4/bin:$PATH"' >> "$HOME/.zshrc"
  echo 'export PATH="/opt/homebrew/opt/php@8.4/sbin:$PATH"' >> "$HOME/.zshrc"
else
  warn "Skipped: Add php@8.4 to PATH."
fi

# reload .zshrc anyway
source "$HOME/.zshrc"

# Set up phpmyadmin
PMA_CFG="$HOMEBREW_PREFIX/etc/phpmyadmin.config.inc.php"

if confirm "Update phpMyAdmin configuration file in $PMA_CFG with proper configuration?"; then
  # Blowfish secret generation and get current username (used by Homebrew MariaDB)
  NEW_SECRET="$(openssl rand -base64 24 | tr -d '\n' | cut -c1-32)"
  CURRENT_USER="$(id -un)"

  # Prepare the patch file
  cat >"/tmp/ieampp_pma.patch" <<EOF
--- phpmyadmin.config.inc.php.default	2026-02-21 01:07:44
+++ phpmyadmin.config.inc.php	2026-02-21 02:57:38
@@ -13,7 +13,7 @@
  * This is needed for cookie based authentication to encrypt the cookie.
  * Needs to be a 32-bytes long string of random bytes. See FAQ 2.10.
  */
-\$cfg['blowfish_secret'] = ''; /* YOU MUST FILL IN THIS FOR COOKIE AUTH! */
+\$cfg['blowfish_secret'] = 'RgRis6hy1Ny+mGoktp/AxpGDAGq97DIE'; /* YOU MUST FILL IN THIS FOR COOKIE AUTH! */
 
 /**
  * Servers configuration
@@ -25,12 +25,16 @@
  */
 \$i++;
 /* Authentication type */
-\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
+\$cfg['Servers'][\$i]['auth_type'] = 'config';
 /* Server parameters */
 \$cfg['Servers'][\$i]['host'] = 'localhost';
+\$cfg['Servers'][\$i]['user'] = 'macosvm';
 \$cfg['Servers'][\$i]['compress'] = false;
-\$cfg['Servers'][\$i]['AllowNoPassword'] = false;
+\$cfg['Servers'][\$i]['AllowNoPassword'] = true;
 
+/* Hide dangerous databases */
+\$cfg['Servers'][\$i]['hide_db'] = 'mysql|performance_schema|information_schema|sys';
+
 /**
  * phpMyAdmin configuration storage settings.
  */
EOF

  # Patch the pma config file
  if ! patch "$PMA_CFG" < /tmp/ieampp_pma.patch; then
    echo "Patch $PMA_CFG failed; printing context and aborting."
    exit 1
  fi


  # create pma shortcut in webroot
  touch "$HOMEBREW_PREFIX/var/www/phpmyadmin"

  ok "phpMyAdmin configuration completed!"
else
  warn "Skipped: phpMyAdmin configuration update."
fi

# Update PHP@8.4 configurations
PHP84_CFG="$HOMEBREW_PREFIX/etc/php/8.4/php.ini"

if confirm "Update PHP 8.4 configuration file in $PHP84_CFG with proper configuration?"; then
  # Prepare the patch file
  cat >"/tmp/ieampp_php84.patch" <<EOF
--- php.ini.default	2026-02-21 01:38:33
+++ php.ini	2026-02-21 01:46:36
@@ -404,7 +404,7 @@
 ; Maximum execution time of each script, in seconds
 ; https://php.net/max-execution-time
 ; Note: This directive is hardcoded to 0 for the CLI SAPI
-max_execution_time = 30
+max_execution_time = 3600
 
 ; Maximum amount of time each script may spend parsing request data. It's a good
 ; idea to limit this time on productions servers in order to eliminate unexpectedly
@@ -430,7 +430,7 @@
 
 ; Maximum amount of memory a script may consume
 ; https://php.net/memory-limit
-memory_limit = 128M
+memory_limit = 512M
 
 ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
 ; Error handling and logging ;
@@ -482,7 +482,7 @@
 ; Development Value: E_ALL
 ; Production Value: E_ALL & ~E_DEPRECATED
 ; https://php.net/error-reporting
-error_reporting = E_ALL
+error_reporting = E_ALL | E_STRICT
 
 ; This directive controls whether or not and where PHP will output errors,
 ; notices and warnings too. Error output is very useful during development, but
@@ -552,7 +552,7 @@
 ; the error message is formatted as HTML or not.
 ; Note: This directive is hardcoded to Off for the CLI SAPI
 ; https://php.net/html-errors
-;html_errors = On
+html_errors = On
 
 ; If html_errors is set to On *and* docref_root is not empty, then PHP
 ; produces clickable error messages that direct to a page describing the error
@@ -694,7 +694,7 @@
 ; Its value may be 0 to disable the limit. It is ignored if POST data reading
 ; is disabled through enable_post_data_reading.
 ; https://php.net/post-max-size
-post_max_size = 8M
+post_max_size = 512M
 
 ; Automatically add files before PHP document.
 ; https://php.net/auto-prepend-file
@@ -846,10 +846,10 @@
 
 ; Maximum allowed size for uploaded files.
 ; https://php.net/upload-max-filesize
-upload_max_filesize = 2M
+upload_max_filesize = 256M
 
 ; Maximum number of files that can be uploaded via a single request
-max_file_uploads = 20
+max_file_uploads = 99
 
 ;;;;;;;;;;;;;;;;;;
 ; Fopen wrappers ;
@@ -961,7 +961,7 @@
 [Date]
 ; Defines the default timezone used by the date functions
 ; https://php.net/date.timezone
-;date.timezone =
+date.timezone = Australia/Melbourne
 
 ; https://php.net/date.default-latitude
 ;date.default_latitude = 31.7667
@@ -1001,7 +1001,7 @@
 ;iconv.output_encoding =
 
 [intl]
-;intl.default_locale =
+intl.default_locale = "en_AU"
 ; This directive allows you to produce PHP errors when some error
 ; happens within intl functions. The value is the level of the error produced.
 ; Default is 0, which does not produce any errors.
@@ -1060,9 +1060,9 @@
 [mail function]
 ; For Win32 only.
 ; https://php.net/smtp
-SMTP = localhost
+;SMTP = localhost
 ; https://php.net/smtp-port
-smtp_port = 25
+;smtp_port = 25
 
 ; For Win32 only.
 ; https://php.net/sendmail-from
@@ -1070,7 +1070,7 @@
 
 ; For Unix only.  You may supply arguments as well (default: "sendmail -t -i").
 ; https://php.net/sendmail-path
-;sendmail_path =
+sendmail_path = "/opt/homebrew/opt/php@8.4/bin/php /opt/homebrew/var/www/mailtodisk/mailtodisk.php"
 
 ; Force the addition of the specified parameters to be passed as extra parameters
 ; to the sendmail binary. These parameters will always replace the value of
EOF

  # Patch the pma config file
  if ! patch "$PHP84_CFG" < /tmp/ieampp_php84.patch; then
    echo "Patch $PHP84_CFG failed; printing context and aborting."
    exit 1
  fi

  # Add mailtodisk
  mkdir -p "$HOMEBREW_PREFIX/var/www/mailtodisk/"
  cat >"$HOMEBREW_PREFIX/var/www/mailtodisk/mailtodisk.php" <<EOF
<?php
// To use this script, set
// sendmail_path = "/path/to/php /path/to/mailtodisk.php"
// in php.ini

// Set the mail redirect folder path
const MAILTODISK_ROOT = "$HOMEBREW_PREFIX/var/www/mailtodisk/";

// Generate a date/time-based random file name
do {
    \$filename = 'mail_' . gmdate('Y-m-d-H-i-s') . '_' . uniqid() . '.txt';
} while(is_file(\$filename));

// Write the mail from stdin to file
\$input = file_get_contents('php://stdin');
file_put_contents(MAILTODISK_ROOT . \$filename, \$input);
EOF

  # And the mail test script
  cat >"$HOMEBREW_PREFIX/var/www/mail_test.php" <<EOF
<?php
ini_set( 'display_errors', 1 );
error_reporting( E_ALL );

\$to = "test@example.com";
\$subject = "PHP Mail Test script";
\$message = "This is a test to check the PHP Mail functionality";
\$headers = "From: emailtest@localhost.local" . "\r\n";

if(mail(\$to, \$subject, \$message, \$headers)) {
    echo "Test email sent successfully to \$to";
} else {
    echo "Mail failed to send";
}

echo "<br><br>By default the emails are not being sent to the Internet. Instead, their contents are redirected to '/opt/homebrew/var/www/mailtodisk' folder. ";
?>
EOF

  # Add php info to webroot
  echo "<?php phpinfo();" > "$HOMEBREW_PREFIX/var/www/phpinfo.php"

  ok "PHP 8.4 configuration completed!"
else
  warn "Skipped: PHP 8.4 configuration update."
fi

# Set up httpd
HTTPD_CFG="$HOMEBREW_PREFIX/etc/httpd/httpd.conf"

if confirm "Update httpd (Apache) configuration file in $HTTPD_CFG with proper configuration?"; then
  # Prepare the patch file
  cat >"/tmp/ieampp_httpd.patch" <<EOF
--- httpd.conf.default	2026-02-21 01:22:02
+++ httpd.conf	2026-02-21 01:24:42
@@ -178,7 +178,8 @@
 #LoadModule speling_module lib/httpd/modules/mod_speling.so
 #LoadModule userdir_module lib/httpd/modules/mod_userdir.so
 LoadModule alias_module lib/httpd/modules/mod_alias.so
-#LoadModule rewrite_module lib/httpd/modules/mod_rewrite.so
+LoadModule rewrite_module lib/httpd/modules/mod_rewrite.so
+LoadModule php_module /opt/homebrew/opt/php@8.4/lib/httpd/modules/libphp.so
 
 <IfModule unixd_module>
 #
@@ -265,7 +266,7 @@
     # It can be "All", "None", or any combination of the keywords:
     #   AllowOverride FileInfo AuthConfig Limit
     #
-    AllowOverride None
+    AllowOverride All
 
     #
     # Controls who can get stuff from this server.
@@ -278,7 +279,7 @@
 # is requested.
 #
 <IfModule dir_module>
-    DirectoryIndex index.html
+    DirectoryIndex index.php index.html
 </IfModule>
 
 #
@@ -289,6 +290,10 @@
     Require all denied
 </Files>
 
+<FilesMatch \.php$>
+    SetHandler application/x-httpd-php
+</FilesMatch>
+
 #
 # ErrorLog: The location of the error log file.
 # If you do not specify an ErrorLog directive within a <VirtualHost>
@@ -362,6 +367,19 @@
     # directives as to Alias.
     #
     ScriptAlias /cgi-bin/ "/opt/homebrew/var/www/cgi-bin/"
+
+    Alias /phpmyadmin /opt/homebrew/share/phpmyadmin
+    <Directory /opt/homebrew/share/phpmyadmin/>
+        Options Indexes FollowSymLinks MultiViews
+        AllowOverride All
+        <IfModule mod_authz_core.c>
+            Require all granted
+        </IfModule>
+        <IfModule !mod_authz_core.c>
+            Order allow,deny
+            Allow from all
+        </IfModule>
+    </Directory>
 
 </IfModule>
EOF

  # Patch the httpd config file
  if ! patch "$HTTPD_CFG" < /tmp/ieampp_httpd.patch; then
    echo "Patch $HTTPD_CFG failed; printing context and aborting."
    exit 1
  fi

  # cleanup webroot
  rm -rf "$HOMEBREW_PREFIX/var/www/index.html"
  rm -rf "$HOMEBREW_PREFIX/var/www/cgi-bin"

  ok "httpd configuration completed!"
else
  warn "Skipped: httpd configuration update."
fi

# ---------- 5) Start services ----------
start_service "httpd"
start_service "mariadb"

ok "All done."
echo
info "Find the webroot folder of Apache..."
echo "The root of your web server is located at '$HOMEBREW_PREFIX/var/www' - Files inside this folder are served at http://localhost:8080"
echo "This folder will open for you in Finder - add it to the sidebar for quick access!"
echo

open "$HOMEBREW_PREFIX/var/www"

info "Next steps:"
echo " - Run 'php -v' command and check if PHP 8.4 is the default PHP interpreter"
echo "   If PHP version is higher than 8.4.x, open another terminal and try again. "
echo " - Run 'composer about' command and check if Composer is installed correctly"
echo " - Run 'mariadb -e \"SELECT VERSION();\"' command and check if database is successfully connected"
echo " - Open http://localhost:8080/ to verify Apache web server is working correctly"
echo " - Open http://localhost:8080/phpinfo.php to verify PHP interpreter is working correctly"
echo " - Open http://localhost:8080/phpmyadmin to verify phpMyAdmin is correctly setup and is connected to MariaDB server"