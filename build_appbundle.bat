@echo off
echo ========================================
echo Generation App Bundle pour Play Store
echo ========================================
echo.

REM Nettoyer les builds precedents
echo [1/4] Nettoyage des builds precedents...
flutter clean
echo.

REM Recuperer les dependances
echo [2/4] Recuperation des dependances...
flutter pub get
echo.

REM Construire l'App Bundle
echo [3/4] Construction de l'App Bundle (.aab)...
flutter build appbundle --release
echo.

REM Afficher les informations
echo [4/4] Termine!
echo.
echo ========================================
echo App Bundle genere avec succes!
echo ========================================
echo.
echo Fichier genere: build\app\outputs\bundle\release\app-release.aab
echo.
echo Ce fichier peut etre uploade sur Google Play Console.
echo.
echo Taille du fichier:
dir build\app\outputs\bundle\release\app-release.aab
echo.
pause


