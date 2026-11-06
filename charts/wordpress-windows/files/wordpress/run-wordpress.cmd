@echo off
rem PHP_DIR contains a space, so php.exe is invoked from a script rather than from the
rem pod's command array (Windows argv quoting and cmd /S disagree about embedded quotes).
echo [win-kube] PHP %PHP_VERSION% serving C:\wp\wordpress on :8080
"%PHP_DIR%\php.exe" %PHP_ARGS% -S 0.0.0.0:8080 -t C:\wp\wordpress C:\config\router.php
