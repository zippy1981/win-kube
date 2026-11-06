@echo off
rem mysql-spike is a bare MySQL zip extract (no entrypoint), so initialize and run it here.
rem The data directory lives under C:\data (emptyDir or PVC); init.sql comes from the Secret.
setlocal
set DATADIR=C:/data/db
if not exist C:\data\db\mysql\ (
  echo [win-kube] Initializing MySQL data directory %DATADIR%
  "%MYSQL_DIR%\bin\mysqld.exe" --no-defaults --initialize-insecure --datadir=%DATADIR% --console
  if errorlevel 1 exit /b 1
)
echo [win-kube] Starting MySQL %MYSQL_VERSION%
"%MYSQL_DIR%\bin\mysqld.exe" --no-defaults --datadir=%DATADIR% --bind-address=0.0.0.0 --port=3306 --mysqlx=OFF --init-file=C:/init/init.sql --console
