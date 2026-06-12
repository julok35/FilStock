# FilStock

FilStock by Julok is a small app for managing an inventory of plastic filament spools for 3D printing enthusiasts.

✅ Utilisation personnelle, éducative, non commerciale : libre (MIT)
❌ Utilisation commerciale : contacter githubjulok35.saddled723@passmail.com pour une licence

---

## Application Android (Tauri v2)

Application mobile Android construite avec **Tauri v2** (frontend HTML/CSS/JS dans `src/`, coque native Rust dans `src-tauri/`).
Les données sont stockées dans un fichier JSON local (`filstock_data.json`).

> L'ancienne version navigateur (`index.html` à la racine) a été supprimée.
> Elle reste disponible dans l'historique git si besoin.

### Prérequis

- [Rust](https://rustup.rs/) (via `rustup`)
- Node.js 18+
- Pour Android : Android SDK, NDK, Java 17, `ANDROID_HOME` défini

### Installation

```bash
npm install
```

### Développement

```bash
npm run dev       # ouvre une fenêtre desktop en mode développement
                  # (sert uniquement à tester l'app sans émulateur Android)
```

### Build

```bash
npm run android   # génère le .apk Android
                  # → src-tauri/gen/android/app/build/outputs/apk/
```

Le build Android est aussi produit automatiquement par GitHub Actions
(workflow **Build Android APK**) : l'APK debug signé est disponible dans
les artefacts du run.

### Localisation des données

| OS | Chemin |
|----|--------|
| Android | `/data/data/com.filstock.app/files/filstock_data.json` |
| Desktop (mode dev) | `%APPDATA%\com.filstock.app\filstock_data.json` |
