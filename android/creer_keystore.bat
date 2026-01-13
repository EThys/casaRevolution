@echo off
echo ========================================
echo Creation du Keystore
echo ========================================
echo.
echo Creation du keystore avec les parametres suivants:
echo   - Alias: upload
echo   - Mot de passe: MUZOLA
echo   - Fichier: upload-keystore.jks
echo.
echo Vous devrez repondre a quelques questions:
echo   - Nom et prenom: (appuyez sur Entree pour utiliser la valeur par defaut)
echo   - Organisation: (appuyez sur Entree pour utiliser la valeur par defaut)
echo   - Ville: (appuyez sur Entree pour utiliser la valeur par defaut)
echo   - Etat/Province: (appuyez sur Entree pour utiliser la valeur par defaut)
echo   - Code pays: (ex: FR, US, CD)
echo.

cd /d %~dp0

keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload -storepass MUZOLA -keypass MUZOLA -dname "CN=Casa, OU=Casa, O=Casa, L=Kinshasa, ST=Kinshasa, C=CD"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo Keystore cree avec succes!
    echo ========================================
    echo.
    echo Le fichier upload-keystore.jks a ete cree dans le dossier android/
    echo Vous pouvez maintenant generer l'APK avec:
    echo   flutter build apk --split-per-abi --release
    echo.
) else (
    echo.
    echo ========================================
    echo Erreur lors de la creation du keystore
    echo ========================================
    echo.
)

pause


