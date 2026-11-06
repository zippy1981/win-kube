@echo off
rem helm test: the front page must render WordPress content (needs a working DB).
curl.exe -fsS %WP_INTERNAL_URL%/ | findstr /i /c:"wp-content" >nul
if errorlevel 1 (
  echo [win-kube] WordPress front page did not render
  exit /b 1
)
echo [win-kube] WordPress front page OK
