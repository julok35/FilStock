# FilStock

FilStock by Julok is a small app for managing an inventory of plastic filament spools for 3D printing enthusiasts.

✅ Utilisation personnelle, éducative, non commerciale : libre (MIT)
❌ Utilisation commerciale : contacter githubjulok35.saddled723@passmail.com pour une licence

---

## Version navigateur (branche `main`)

Ouvrir `index.html` directement dans n'importe quel navigateur moderne. Aucune installation requise. Les données sont stockées dans `localStorage`.

## Application native Android + iOS (Flutter)

Application mobile construite avec **Flutter** (Dart). Toutes les fonctionnalités de la
version web sont conservées : bobines, supports, couleurs/matières personnalisées,
codes uniques, journal d'activité, thème clair/sombre, groupement & tri, export/import JSON.

Les données sont stockées dans un fichier JSON local (`filstock_data.json`) dans le
dossier documents de l'application. Le format est compatible avec les exports de la
version web, donc l'import des anciennes données fonctionne directement.

### Prérequis

- [Flutter](https://docs.flutter.dev/get-started/install) (canal stable, ≥ 3.27)
- Android : Android SDK + Java 17
- iOS : Xcode (macOS uniquement)

### Développement

```bash
flutter pub get      # installer les dépendances
flutter run          # lancer sur l'appareil / l'émulateur connecté
flutter analyze      # analyse statique
flutter test         # tests unitaires
```

### Build

```bash
flutter build apk --release                 # APK Android
#   → build/app/outputs/flutter-apk/app-release.apk

flutter build appbundle --release           # AAB (Google Play)

flutter build ios --release --no-codesign   # build iOS (validation sans certificat)
```

L'APK est aussi construit automatiquement en CI (onglet **Actions** → artefact
`filstock-android-apk`).
