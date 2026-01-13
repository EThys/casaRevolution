#!/bin/bash

echo "========================================"
echo "Generation APK Optimise"
echo "========================================"
echo ""

# Nettoyer les builds precedents
echo "[1/5] Nettoyage des builds precedents..."
flutter clean
echo ""

# Recuperer les dependances
echo "[2/5] Recuperation des dependances..."
flutter pub get
echo ""

# Construire l'APK avec split par ABI
echo "[3/5] Construction de l'APK optimise (split par architecture)..."
flutter build apk --split-per-abi --release
echo ""

# Afficher les tailles des APK generes
echo "[4/5] Verification des tailles des APK..."
echo ""
echo "APK generes dans: build/app/outputs/flutter-apk/"
echo ""
ls -lh build/app/outputs/flutter-apk/*.apk 2>/dev/null || echo "Aucun APK trouve"
echo ""

echo "[5/5] Termine!"
echo ""
echo "Les APK optimises ont ete generes dans: build/app/outputs/flutter-apk/"
echo ""
echo "APK disponibles:"
echo "  - app-arm64-v8a-release.apk (pour la plupart des appareils modernes)"
echo "  - app-armeabi-v7a-release.apk (pour les appareils plus anciens)"
echo "  - app-x86_64-release.apk (pour les emulateurs)"
echo ""
echo "Choisissez l'APK selon l'architecture de votre appareil cible."
echo ""


