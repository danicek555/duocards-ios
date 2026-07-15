# DuoCards pro iOS — implementační plán

Stav specifikace: 15. 7. 2026  
Zdroj pravdy: aktuální implementace v `src/`, nový kontrakt v
`backend/src/`, legacy API routy v `src/app/api/` a datový model v
`backend/prisma/schema.prisma`.

## 1. Cíl a význam „1:1“

Cílem je nativní Swift aplikace pro iPhone a iPad, která používá stejný účet a stejná data jako webová aplikace. Web i iOS budou připojené k jednomu backendu a jedné PostgreSQL databázi.

„1:1“ zde znamená:

- stejnou dostupnou funkcionalitu, data, limity, texty a chybové/loading/empty stavy;
- stejný vizuální jazyk DuoCards: midnight neutrály, indigo primary, violet AI, emerald success a amber coins;
- stejné serverové chování a synchronizaci mezi webem a iOS;
- nativní mobilní navigaci a ovládání podle iOS konvencí;
- nekopírovat známé bezpečnostní chyby, race conditions ani placeholdery jako hotové funkce.

Současný web pod šířkou 1024 px kompletně překrývá `MobileNotSupportedOverlay`. Neexistuje proto mobilní webová předloha, kterou by šlo pixelově překreslit. Funkční a vizuální parita bude přesná, ale rozložení telefonu musí vzniknout nativně.

## 2. Jedna platforma, dva klienti

```text
Web (Next.js) ─┐
               ├── Versionované HTTPS API ── aplikační služby ── PostgreSQL
iOS (SwiftUI) ─┘                           ├── Redis/rate limits
                                           ├── OpenAI
                                           ├── Resend
                                           ├── media storage
                                           └── Ably / live rooms
```

Pravidla:

- Swift aplikace se nikdy nepřipojuje přímo k PostgreSQL.
- Databázové, OpenAI, Resend, Redis, OAuth a Ably secret klíče zůstávají pouze na serveru.
- Do iOS bundlu patří jen veřejný base URL API a veřejná telemetry konfigurace.
- Nový Fastify backend poskytuje první vertikálu jako `/api/v1`; web ji
  používá přes same-origin proxy a iOS přímo.
- Nepřemigrované create, AI, public a live operace dočasně zůstávají na
  legacy Next.js `/api`, aby bylo možné migrovat po funkčních řezech.
- Klientské SwiftUI obrazovky závisejí na protokolu `DuoCardsAPI`, takže
  rozšiřování kontraktu nebude vyžadovat přepis UI.

## 3. Inventura skutečně existujících funkcí

### Identity

- login e-mail/heslo;
- registrace s nickname, locale a silným heslem;
- šestimístné ověření e-mailu a resend;
- forgotten/reset password;
- Google a Facebook OAuth (zatím pouze webový callback);
- 29 jazyků UI, včetně RTL pro arabštinu a hebrejštinu;
- logout a automatická sedmidenní cookie session.

### Dashboard a sady

- přehled počtu sad, slov a coinů;
- daily reward;
- hledání názvu, jazykové filtry a tagy;
- ruční create/edit/delete sady;
- až 100 sad, 100 karet v editoru, 5 tagů na sadu a 20 unikátních tagů;
- private/public stav, veřejný kód a joined/shared stav;
- AI generování sad, CEFR A1–C2, topic a volitelná média;
- AI překlad, výslovnost, audio, obrázky, OCR a AI chat.

### Studium

- náhodné zamíchání při otevření sady;
- flip přední/zadní strany;
- previous/next;
- text, překlad, difficulty barva, výslovnost, obrázek a audio;
- completion coin bag na posledním indexu.

Současná aplikace nemá spaced repetition, správně/špatně, mastery ani uložený study progress. Tyto funkce nejsou součástí 1:1 parity.

### Sdílení

- veřejná knihovna, search, tag filter a stránkování;
- preview slov;
- přidání snapshot kopie do vlastního účtu;
- přidání přes kód `XXXX-XXXX`.

### Live

- host/join/guest flow a deep link `?room=CODE`;
- Ably presence, realtime konfigurace a chat;
- multi-set výběr, 5–30minutová délka a chat toggle;
- `practice` mód se sdílenými kartami;
- ukončení a historie hostovaných her.

`classic_duel`, `speed_run`, `team_battle` a `survival` jsou dnes jen placeholdery bez otázek, odpovědí a skóre. Pro paritu budou označené „Připravujeme“, případně skryté za feature flag; jejich skutečný gameplay je nový scope.

### Co dnes neexistuje

- premium/subscription a nákup coinů;
- StoreKit nebo jiná platba;
- push notifikace;
- admin/role/ban/report workflow;
- smazání účtu;
- SRS, statistiky, streak, notes a nové learning games.

Tyto položky nesmí být prezentované jako součást současné parity. Některé z nich jsou ale nutné jako release compliance gate.

## 4. Nativní informační architektura

### iPhone

Hlavní `TabView`:

1. **Sady** — seznam, search/filters, create, AI create a detail studia.
2. **Knihovna** — veřejné sady, preview, join a join kódem.
3. **Live** — host/join, lobby, practice a historie.
4. **Profil** — účet, locale, coiny, daily reward, coin guide, privacy a logout.

Další pravidla:

- Studijní karta se otevírá jako plnohodnotná `NavigationStack` destination.
- Ruční editor je vícekrokový flow: metadata → karty → média/AI → public/summary.
- OCR je samostatný sheet s výběrem obrázku, segmentací a potvrzením vybraných slov.
- AI chat je dostupný přes floating action button nebo toolbar, ne jako permanentní desktopový overlay.
- Toasty budou nahrazené jednotným in-app bannerem; potvrzení a kritické chyby použijí nativní dialog/sheet.

### iPad

- `NavigationSplitView` zachová desktopovou logiku sidebaru.
- Editor může využít dvousloupcové rozložení.
- Study card zůstane centrovaná s omezenou maximální šířkou.

## 5. Swift architektura

Minimální platforma: iOS/iPadOS 17.0.  
UI: SwiftUI.  
Jazyk: Swift 6, strict concurrency.  
První verze bez externích UI závislostí.

### Vrstvy

```text
DuoCardsApp
├── AppSession / AppRouter / AppEnvironment
├── Features
│   ├── Auth
│   ├── Sets
│   ├── Study
│   ├── Creator
│   ├── PublicLibrary
│   ├── Coins
│   ├── AIChat
│   ├── LiveGame
│   └── Settings
├── Domain
│   ├── Models
│   └── UseCases
└── Core
    ├── Networking
    ├── Persistence
    ├── Media
    ├── DesignSystem
    ├── Localization
    └── Observability
```

### Technická rozhodnutí

- `async/await` a `URLSession` pro síť;
- `Codable` DTO oddělená od lokálních view modelů;
- `@Observable` + `@MainActor` pro UI stav;
- `HTTPCookieStorage` pouze pro první prototyp proti legacy API;
- Keychain access/refresh token pro produkční session;
- SwiftData jako offline/read cache až po stabilizaci kontraktu;
- vlastní media loader pro současné base64 `dataUrl` odpovědi;
- `AVFoundation` pro audio;
- `PhotosPicker` a systémové pickery místo plného přístupu do fotek;
- `NavigationStack`, deep links a universal links;
- Ably Swift SDK až v live milestone;
- StoreKit 2 pouze pokud se později skutečně přidá nákup coinů.

## 6. Backend kontrakt pro oba klienty

### Aktuální přechodná vertikála

Fastify backend nyní poskytuje:

- `/api/v1/auth/register`, `/verify`, `/resend`, `/login`, `/me` a
  `/logout`;
- `GET/POST /api/v1/flashcard-sets` a
  `GET/PATCH/DELETE /api/v1/flashcard-sets/:id`;
- `/api/v1/user/coins`;
- `/api/v1/word-images/:id` a `/api/v1/word-audio/:id`.

První zapisovací kontrakt podporuje privátní textové sady. Při editaci
zachovává stabilní ID existujících karet a jejich média; při skutečném
smazání karty nebo celé sady uklízí odpojené image/audio záznamy v jedné
databázové transakci. Public stav, public code a AI/media write operace se
zatím přes tento minimální editor nemění.

Web volá tyto cesty přes `/shared-api` rewrite. iOS volá `/api/v1`
přímo. Oba klienti v tomto prototypu sdílejí kompatibilní sedmidenní HMAC
cookie session; stejný `AUTH_SECRET` proto musí být nastaven v obou serverech.
Registrační kód je navíc svázaný s nezávislým registračním pokusem a
256bitovou HttpOnly cookie. Cizí opakovaná registrace stejného e-mailu tak
nemůže přepsat heslo ani ověřit pokus jiného zařízení.

### Cílové `/api/v1`

- jednotný error envelope
  `{ error: { code, message, details? }, requestId }` (hotovo v první vertikále);
- OpenAPI specifikace a generované/ověřované DTO;
- access token s krátkou expirací + rotovaný refresh token;
- serverový seznam sessions a revokace;
- native Google/Facebook ID-token exchange;
- Sign in with Apple a account linking;
- idempotency key pro mutace;
- cursor pagination a verzování entit;
- ETag/conditional requests pro cache;
- binární nebo signed URL média místo velkých base64 JSON payloadů;
- samostatný word CRUD místo smazání a znovuvytvoření všech slov při editaci;
- centralizované `401`, `402`, `409`, `422`, `429` a `Retry-After` chování.

## 7. P0 bezpečnostní blokátory před TestFlightem

1. **Session auth** — dnešní HMAC cookie nemá refresh, revokaci ani seznam sessions; logout jen smaže cookie klienta. Přidat serverové sessions a odstranit produkční možnost známého fallback secretu.
2. **Native OAuth** — současný callback končí na webovém `/dashboard`. Přidat bezpečný native token exchange/callback a Keychain storage.
3. **Coiny** — completion endpoint dnes přijímá částku od klienta a coin operace nejsou atomické. Částku musí vypočítat server, ověřit vlastnictví a transakčně vytvořit immutable ledger záznam.
4. **Live autorita** — dnešní Ably token endpoint není room-scoped a role hosta je klientská. Přidat serverový `LiveRoom`, členství, role a capability omezené na konkrétní room.
5. **Média** — validovat vlastnictví, MIME a velikost; odstranit orphan records a přesunout data mimo PostgreSQL.
6. **API read side effects** — `GET /flashcard-sets` nesmí opravovat tagy zápisem během čtení.
7. **Identity provoz** — před horizontálním škálováním přesunout rate limity
   do sdíleného Redis store, přidat per-attempt počítadlo chybných OTP a
   transakční e-mailový outbox s retry/observabilitou.

## 8. App Store release gates

Tyto položky nejsou rozšířením produktu, ale podmínkou bezpečného vydání:

- nabídnout odpovídající privacy-preserving login vedle Google/Facebook; v praxi implementovat Sign in with Apple;
- umožnit zahájit smazání účtu přímo v aplikaci;
- veřejné sady a live chat považovat za user-generated content: filtrování, report, blokování a dostupný kontakt;
- privacy policy v aplikaci a App Store metadata;
- jasný souhlas/disclosure před odesíláním uživatelského obsahu třetí straně/AI;
- připravit plně funkční review/demo účet;
- pokud vznikne prodej AI coinů, digitální měna musí používat StoreKit/IAP a serverové ověření transakcí.

Referenční pravidla:

- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/support/offering-account-deletion-in-your-app
- https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession

## 9. Milníky

### M0 — specifikace, skeleton a bezpečný kontrakt

Výstup:

- Xcode projekt, design tokens a feature struktura;
- real/mock `DuoCardsAPI`;
- legacy cookie klient pro prototyp;
- návrh `/api/v1` a OpenAPI;
- opravené coin/reward transakce;
- návrh native sessions/OAuth;
- CI build, unit test target a základní UI smoke test.

Definition of done:

- projekt se sestaví bez signing závislosti;
- žádný secret není v iOS bundlu;
- API base URL lze přepnout pro local/staging/production;
- auth expirace přepne celý klient konzistentně do signed-out stavu.

### M1 — Core Study MVP

Výstup:

- login, registrace, verification, resend, reset a logout;
- session restore;
- seznam sad, search a základní filtry;
- detail sady a zamíchání;
- flip, previous/next, obrázek, pronunciation a audio;
- coin balance, daily reward a bezpečný completion reward;
- minimální create/edit/delete;
- loading, empty, offline, unauthorized a retry stavy.

Toto je první interně použitelná verze.

### M2 — Creator + AI beta

Výstup:

- kompletní editor do 100 karet;
- jazyky, tagy, public toggle a code preview;
- image/audio upload;
- translate, auto-translate, pronunciation;
- OCR včetně výběru slov/frází;
- AI generování, CEFR, cost preview a volitelná média;
- AI chat a sdílený moderation cooldown.

### M3 — Sharing, identity a dashboard parita

Výstup:

- public katalog, hledání, tagy, pagination a preview;
- join snapshot a join kódem;
- všechny dashboard filtry a limity;
- native Google/Facebook + Sign in with Apple;
- locale synchronizace, settings, coin guide a daily reward;
- report/block flow pro veřejný obsah.

### M4 — Live parita

Výstup:

- server-authoritative room a bezpečný Ably token;
- host/join/guest deep links;
- presence, reconnect a background/foreground recovery;
- multi-set `practice`, lobby, start a timer;
- chat toggle, rate limit, moderation, report/block;
- host end, guest end modal a spolehlivý zápis historie;
- další čtyři módy jen jako označené placeholdery.

### M5 — úplná vizuální a behaviorální parita

Výstup:

- všech 29 lokalizací a RTL audit;
- light/dark, Dynamic Type, VoiceOver a Reduce Motion;
- stejné limity, texty, potvrzení a edge stavy;
- media progress, cache a retry;
- iPhone SE/standard/Max a iPad layout QA;
- snapshot testy design komponent a kritických obrazovek;
- TestFlight beta a App Store checklist.

### M6 — nový produktový scope až po paritě

- SRS/FSRS, mastery a practice history;
- streak/statistiky a notes;
- spelling, přesmyčky, typing a storytelling games;
- deduplikace AI obsahu;
- StoreKit coin packs/premium;
- push notifikace;
- pokročilý admin/moderation panel.

## 10. Testovací strategie

### Automatické testy

- unit: password policy, DTO decoding, error mapping, reward rules a state machines;
- API contract: web i iOS fixture proti stejné OpenAPI specifikaci;
- integration: login → list → detail → media → logout;
- UI: auth, empty dashboard, otevření sady, flip, next/previous;
- snapshot: design tokens, auth card, set cell a study card ve světlém/tmavém režimu;
- live: room membership, reconnect, host authority a duplicate event idempotence.

### Ruční matrix

- iPhone SE, standardní iPhone, Pro Max a iPad;
- portrait, landscape na iPadu, split view;
- light/dark, větší text, VoiceOver, Reduce Motion;
- pomalá síť, offline, expirace session, 401/429 a částečné selhání médií;
- čeština, angličtina, dlouhé německé texty a RTL arabština/hebrejština;
- background/foreground během uploadu, audio a live room.

## 11. Odhad pro jednoho vývojáře na plný úvazek

Odhad je orientační a předpokládá zachování současného backendu:

| Milník | Odhad |
|---|---:|
| M0 | 1–2 týdny |
| M1 | 3–4 týdny |
| M2 | 4–6 týdnů |
| M3 | 2–4 týdny |
| M4 | 4–6 týdnů |
| M5 | 2–4 týdny |

Celkem pro bezpečnou plnou paritu přibližně 16–26 vývojářských týdnů. První použitelný M1 build může být výrazně dříve.

## 12. Stav implementace a další řez

První dvě coding iterace jsou implementované:

1. samostatný Fastify backend a `/api/v1` vertikála;
2. webový proxy adapter a compatibility identity aliasy bez legacy auth flow;
3. Xcode/SwiftUI projekt a design systém podle `globals.css`;
4. `DuoCardsAPI`, cookie session restore, e-mail login/logout, registrace,
   šestimístné ověření a resend;
5. dashboard, seznam a detail sad;
6. shuffle, flip a previous/next studium;
7. nativní vytvoření, úprava a smazání privátní textové sady;
8. backend i iOS test target a sestavení z příkazové řádky.

Další identity vertikála bude forgotten/reset password. Potom naváže
dashboard search/filtry, daily reward a bezpečný completion reward. Plná
1:1 parita zůstává rozdělená do milníků M1–M5 výše.
