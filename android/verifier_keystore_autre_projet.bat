@echo off
echo ========================================
echo Verification du Keystore dans l'Autre Projet
echo ========================================
echo.
echo Ce script va verifier l'empreinte SHA1 du keystore
echo dans votre autre projet pour confirmer qu'il correspond
echo a celui attendu par le Play Store.
echo.
set /p KEYSTORE_PATH="Entrez le chemin complet vers le keystore dans l'autre projet (ex: D:\monAutreProjet\android\app\upload-keystore.jks): "

if not exist "%KEYSTORE_PATH%" (
    echo.
    echo ERREUR: Le fichier n'existe pas a cet emplacement!
    echo Verifiez le chemin et reessayez.
    pause
    exit /b 1
)

echo.
echo Verification de l'empreinte SHA1...
echo.
keytool -list -v -keystore "%KEYSTORE_PATH%" -storepass MUZOLA | findstr /C:"SHA1:" /C:"Creation date:"

echo.
echo ========================================
echo Empreinte attendue par Play Store:
echo SHA1: D2:26:39:78:08:F4:BC:1F:2D:47:E0:1C:BE:C6:59:9D:DA:1C:F7:CA
echo ========================================
echo.
echo Si l'empreinte correspond, copiez ce fichier vers:
echo D:\myproject\casaNayo\casaRevolution\android\app\upload-keystore.jks
echo.
pause


