# Web favicon and link preview (OG image)

**Date:** June 16, 2026

## Goal

Use the iOS StockPulse app icon for the browser tab favicon and for link-sharing previews on `https://tryan.app`.

## Source

`ios/StockPulse/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (1024×1024)

## Files added (`web/public/`)

| File | Size | Purpose |
|------|------|---------|
| `favicon-16x16.png` | 16×16 | Browser tab (small) |
| `favicon-32x32.png` | 32×32 | Browser tab |
| `apple-touch-icon.png` | 180×180 | iOS home screen / bookmarks |
| `og-image.png` | 512×512 | Open Graph / Twitter link preview |

Generated with macOS `sips` from the app icon.

## HTML changes (`web/index.html`)

- `<link rel="icon">` for 16px and 32px PNGs
- `<link rel="apple-touch-icon">`
- `og:*` meta tags (title, description, url, image)
- `twitter:card` summary + image

`og:image` and `twitter:image` use absolute URLs: `https://tryan.app/og-image.png`

## Build / deploy

Vite copies `public/` to `dist/` root on build.

```bash
cd web && npm run build
rsync -avz --delete dist/ mspclientpro:/var/www/tryan.app/
```

Verify:

```bash
curl -sI https://tryan.app/favicon-32x32.png
curl -sI https://tryan.app/og-image.png
```

## Regenerate icons after app icon change

```bash
ICON="ios/StockPulse/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
PUB="web/public"
sips -z 32 32   "$ICON" --out "$PUB/favicon-32x32.png"
sips -z 16 16   "$ICON" --out "$PUB/favicon-16x16.png"
sips -z 180 180 "$ICON" --out "$PUB/apple-touch-icon.png"
sips -z 512 512 "$ICON" --out "$PUB/og-image.png"
```
