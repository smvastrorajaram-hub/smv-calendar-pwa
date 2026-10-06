# SMV CALENDAR independent GitHub Pages PWA

This repository contains only the deployment workflow. Runtime files are always pulled from:

`smvastrorajaram-hub/smvastroservices` → `public/horoscope/`

The Calendar shell from `public/horoscope/calendar/` is promoted to this site's root while retaining the current shared Horoscope calculation/WASM/location assets.

Target custom domain:

`calendar.smvastroservices.in`

## First setup

1. Create this repository as a **Public** GitHub repository.
2. Upload these files preserving `.github/workflows/deploy-pages.yml`.
3. Repository **Settings → Pages → Build and deployment → Source → GitHub Actions**.
4. **Actions → Deploy SMV CALENDAR PWA → Run workflow**.
5. After the first successful deployment, **Settings → Pages → Custom domain**:
   `calendar.smvastroservices.in`
6. At your DNS provider create:
   - Type: `CNAME`
   - Name/Host: `calendar`
   - Target: `smvastrorajaram-hub.github.io`

Firebase Authorized Domains is not required for current Calendar-only functionality, but adding `calendar.smvastroservices.in` is harmless if future authenticated features are added.

No PAT/token is required. The workflow reads the public main source and deploys to its own Pages site.

The workflow also checks the main source every 6 hours. Use **Run workflow** after an important SMV ASTRO update when you want immediate sync.
