# Industry Experience customised XAMPP for Windows

This version of XAMPP simplify the software structure with the latest version of software distros for use in Monash Industry Experience Studio Projects. 

You can find the latest release and download [here](https://github.com/ugie-cake/xampp/releases/latest). 

## Installation

0. Ensure the xampp package is extracted into the root of C: drive.

The zip package you have downloaded already contain `xampp` folder inside. You can extract all files directly to the root of C: drive. 

As some path are hard-coded in XAMPP, the software package only works in the xampp folder in the root of a drive. 

1. Install Visual C++ Runtime

This is required by many components in this software distro. Navigate to `C:\xampp\_vcredist` folder, and execute the "install.bat" file as Administrator

2. Start `xampp-control.exe` as Administrator

You'll need to start XAMPP Control Panel as administrator to install Apache and MariaDB as system service. Usually the control panel will automatically requires admin rights. If not, right click on the icon, and select "Run as administrator"

3. Before installing services, make sure Apache and MariaDB/MySQL are not started

You'll know these services are not started yet if PID and Port fields are empty, and the first action button is "Start". You can stop these services by click "Stop" button. 

4. Install Apache and MariaDB/MySQL as system services

Installing Apache and MariaDB/MySQL as system services will allow the web and database server to start automatically when your computer boots up. It also has the added benefits of more stable services and less chance of database corruption. 

To install these modules as services, click the red crosses in front of each row, and follow on-screen instructions. Once they're installed as services, the red cross button become a green tick button. You can now manually start Apache and MySQL/MariaDB by clicking "Start" action button on each row, or just restart your computer, where these services will start on their own. 

5. Test web and database servers

Go to the browser, and visit http://localhost:8080
- If you see a file indexing list (Index of /), then the Apache web server is working
- If you execute `phpinfo.php` file in the file list and you can see "PHP Version" page, then PHP interpreter is working
- If you visit "phpmyadmin" file in the file list and you can see "phpMyAdmin" page without noticable errors, then the database server is working

## Software versions in this distro

- Apache: v2.4.66 (Apache Lounge)
- PHP: v8.4.16 VS17 x64 Thread-safe
- MariaDB: v11.8.6 Win x64
- phpMyAdmin: v5.2.3

Last updated: February 2026

## Other features

1. mailtodisk

In this distro, emails send through PHP's `mail()` will not actually be delivered through SMTP or sendmail. Instead, a simple PHP script located in `/xampp/mailtodisk` will intercept emails and store them as `.txt` files in the same folder. This way you can inspect emails sent immediately, and not to worry about spamming real email addresses during development. 
