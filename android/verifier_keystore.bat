@echo off
echo ========================================
echo Verification du keystore
echo ========================================
echo.

if not exist "%~dp0app\upload-keystore.jks" (
    echo ERREUR: Le keystore n'existe pas dans: %~dp0app\upload-keystore.jks
    pause
    exit /b 1
)

echo Keystore trouve: %~dp0app\upload-keystore.jks
echo.
echo Informations du keystore:
echo.
keytool -list -v -keystore "%~dp0app\upload-keystore.jks" -storepass MUZOLA
echo.
echo.
echo Empreinte SHA1 attendue par Play Store:
echo D2:26:39:78:08:F4:BC:1F:2D:47:E0:1C:BE:C6:59:9D:DA:1C:F7:CA
echo.
pause
