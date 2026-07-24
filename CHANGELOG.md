# Changelog

Všechny podstatné změny aplikace jsou zaznamenány v tomto souboru.
Formát vychází z [Keep a Changelog](https://keepachangelog.com/cs/1.1.0/),
verzování dle [SemVer](https://semver.org/lang/cs/).

## [1.0.0-beta.1] - 2026-07-23

První beta verze pro TestFlight. Marketing version 1.0.0, build 1.

### Přidáno

- Nativní SwiftUI aplikace pro iOS 17+ bez externích závislostí
- Přihlášení a registrace přes sdílený DuoCards backend (`/api/v1`, cookie session)
- CRUD soukromých textových balíčků kartiček
- Obnova hesla — vložení tokenu z e-mailu nebo celého HTTPS odkazu
- Konfigurace Debug i Release používá produkční Cloud Run backend;
  adresu lze přepsat launch argumentem nebo environment proměnnou
- Konfigurovatelná záložní API adresa (`DUOCARDS_API_FALLBACK_URL`)
  použitá po síťové chybě nebo odpovědi 502/503/504

### Známá omezení

- Automatické otevření odkazu z resetovacího e-mailu vyžaduje publikované
  AASA a Associated Domains entitlement — do té doby uživatel vloží odkaz ručně
