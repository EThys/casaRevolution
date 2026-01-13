@echo off
echo ========================================
echo Remplacement du Keystore
echo ========================================
echo.
echo ATTENTION: Ce script va remplacer le keystore actuel
echo par le keystore original depuis votre autre projet.
echo.
echo Le keystore actuel a ete cree le 29 dec. 2025 (aujourd'hui)
echo et n'est PAS celui utilise pour la premiere version sur Play Store.
echo.
set /p SOURCE_PATH="Entrez le chemin complet vers le keystore ORIGINAL (ex: D:\monAutreProjet\android\app\upload-keystore.jks): "

if not exist "%SOURCE_PATH%" (
    echo.
    echo ERREUR: Le fichier n'existe pas a cet emplacement!
    echo Verifiez le chemin et reessayez.
    pause
    exit /b 1
)

echo.
echo Verification de l'empreinte du keystore source...
echo.
keytool -list -v -keystore "%SOURCE_PATH%" -storepass MUZOLA | findstr /C:"SHA1:" /C:"Creation date:"

echo.
echo Empreinte attendue: D2:26:39:78:08:F4:BC:1F:2D:47:E0:1C:BE:C6:59:9D:DA:1C:F7:CA
echo.
set /p CONFIRM="L'empreinte correspond-elle? (O/N): "

if /i not "%CONFIRM%"=="O" (
    echo.
    echo Operation annulee.
    pause
    exit /b 1
)

echo.
echo Sauvegarde du keystore actuel...
if exist "app\upload-keystore.jks" (
    copy "app\upload-keystore.jks" "app\upload-keystore.jks.backup" /Y
    echo Keystore actuel sauvegarde dans: app\upload-keystore.jks.backup
)

echo.
echo Copie du keystore original...
copy "%SOURCE_PATH%" "app\upload-keystore.jks" /Y

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================
    echo Keystore remplace avec succes!
    echo ========================================
    echo.
    echo Verification de l'empreinte du nouveau keystore...
    echo.
    keytool -list -v -keystore app\upload-keystore.jks -storepass MUZOLA | findstr /C:"SHA1:" /C:"Creation date:"
    echo.
    echo Vous pouvez maintenant generer l'App Bundle avec:
    echo   flutter build appbundle --release
    echo.
) else (
    echo.
    echo ERREUR lors de la copie!
    echo.
)

pause


