@echo off
rem Init container: fetch WordPress into the shared C:\wp volume on first start and
rem install the env-driven wp-config.php. Uses nanoserver's built-in curl.exe and tar.exe.
if not exist C:\wp\wordpress\wp-includes\version.php (
  echo [win-kube] Downloading %WORDPRESS_DOWNLOAD_URL%
  curl.exe -fsSL --retry 5 -o C:\wp\wordpress.zip %WORDPRESS_DOWNLOAD_URL%
  if errorlevel 1 exit /b 1
  tar.exe -xf C:\wp\wordpress.zip -C C:\wp
  if errorlevel 1 exit /b 1
  del C:\wp\wordpress.zip
)
copy /y C:\config\wp-config.php C:\wp\wordpress\wp-config.php
if errorlevel 1 exit /b 1
echo [win-kube] WordPress ready in C:\wp\wordpress
