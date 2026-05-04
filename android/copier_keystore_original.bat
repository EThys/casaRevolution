@echo off
echo ========================================
echo Copie du keystore original
echo ========================================
echo.

REM Chemin du projet de reference (meme keystore / Play Store)
set ORIGINAL_PROJECT_PATH=D:\myproject\casaFinale\casaRevolution

REM Vérifier si le chemin existe
if not exist "%ORIGINAL_PROJECT_PATH%" (
    echo ERREUR: Le chemin specifie n'existe pas: %ORIGINAL_PROJECT_PATH%
    pause
    exit /b 1
)

REM Chercher le keystore dans le projet original
set ORIGINAL_KEYSTORE=
if exist "%ORIGINAL_PROJECT_PATH%\android\app\upload-keystore.jks" (
    set ORIGINAL_KEYSTORE=%ORIGINAL_PROJECT_PATH%\android\app\upload-keystore.jks
) else if exist "%ORIGINAL_PROJECT_PATH%\android\upload-keystore.jks" (
    set ORIGINAL_KEYSTORE=%ORIGINAL_PROJECT_PATH%\android\upload-keystore.jks
) else if exist "%ORIGINAL_PROJECT_PATH%\upload-keystore.jks" (
    set ORIGINAL_KEYSTORE=%ORIGINAL_PROJECT_PATH%\upload-keystore.jks
) else (
    echo ERREUR: Keystore non trouve dans le projet original.
    echo Cherche dans:
    echo   - %ORIGINAL_PROJECT_PATH%\android\app\upload-keystore.jks
    echo   - %ORIGINAL_PROJECT_PATH%\android\upload-keystore.jks
    echo   - %ORIGINAL_PROJECT_PATH%\upload-keystore.jks
    pause
    exit /b 1
)

echo.
echo Keystore original trouve: %ORIGINAL_KEYSTORE%
echo.

REM Vérifier l'empreinte SHA1 du keystore original
echo Verification de l'empreinte SHA1 du keystore original...
echo.
keytool -list -v -keystore "%ORIGINAL_KEYSTORE%" -storepass MUZOLA | findstr /C:"SHA1"
echo.

REM Demander confirmation
set /p CONFIRM="Voulez-vous copier ce keystore vers android/app/upload-keystore.jks? (O/N): "
if /i not "%CONFIRM%"=="O" (
    echo Operation annulee.
    pause
    exit /b 0
)

REM Créer le dossier de destination s'il n'existe pas
if not exist "%~dp0app" mkdir "%~dp0app"

REM Sauvegarder l'ancien keystore s'il existe
if exist "%~dp0app\upload-keystore.jks" (
    echo.
    echo Sauvegarde de l'ancien keystore...
    move /Y "%~dp0app\upload-keystore.jks" "%~dp0app\upload-keystore.jks.backup.%date:~-4,4%%date:~-7,2%%date:~-10,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
)

REM Copier le keystore
echo.
echo Copie du keystore...
copy /Y "%ORIGINAL_KEYSTORE%" "%~dp0app\upload-keystore.jks"
if errorlevel 1 (
    echo ERREUR: La copie a echoue.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Copie reussie!
echo ========================================
echo.
echo Verification de l'empreinte SHA1 du keystore copie...
echo.
keytool -list -v -keystore "%~dp0app\upload-keystore.jks" -storepass MUZOLA | findstr /C:"SHA1"
echo.
echo Le keystore a ete copie avec succes vers: %~dp0app\upload-keystore.jks
echo.
pause
