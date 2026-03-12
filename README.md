# FilStock

FilStock by Julok is a small app for managing an inventory of plastic filament spools for 3D printing enthusiasts.

✅ Utilisation personnelle, éducative, non commerciale : libre (MIT)
❌ Utilisation commerciale : contacter githubjulok35.saddled723@passmail.com pour une licence

---

## Version navigateur (branche `main`)

Ouvrir `index.html` directement dans n'importe quel navigateur moderne. Aucune installation requise. Les données sont stockées dans `localStorage`.

## Version application native Windows + Android (branche `native-app`)

Application de bureau Windows et mobile Android construite avec **Tauri v2**.
Les données sont stockées dans un fichier JSON local (`filstock_data.json`).

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
npm run dev       # ouvre la fenêtre desktop en mode développement
```

### Build

```bash
npm run build     # génère le .exe / .msi Windows
                  # → src-tauri/target/release/

npm run android   # génère le .apk Android
                  # → src-tauri/gen/android/app/build/outputs/apk/
```

### Localisation des données

| OS | Chemin |
|----|--------|
| Windows | `%APPDATA%\com.filstock.app\filstock_data.json` |
| Android | `/data/data/com.filstock.app/files/filstock_data.json` |
