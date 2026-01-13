#!/bin/bash

echo "========================================"
echo "Generation App Bundle pour Play Store"
echo "========================================"
echo ""

# Nettoyer les builds precedents
echo "[1/4] Nettoyage des builds precedents..."
flutter clean
echo ""

# Recuperer les dependances
echo "[2/4] Recuperation des dependances..."
flutter pub get
echo ""

# Construire l'App Bundle
echo "[3/4] Construction de l'App Bundle (.aab)..."
flutter build appbundle --release
echo ""

# Afficher les informations
echo "[4/4] Termine!"
echo ""
echo "========================================"
echo "App Bundle genere avec succes!"
echo "========================================"
echo ""
echo "Fichier genere: build/app/outputs/bundle/release/app-release.aab"
echo ""
echo "Ce fichier peut etre uploade sur Google Play Console."
echo ""
echo "Taille du fichier:"
ls -lh build/app/outputs/bundle/release/app-release.aab 2>/dev/null || echo "Fichier non trouve"
echo ""


