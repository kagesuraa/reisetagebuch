# Reisetagebuch — Entwicklungsprotokoll

Aufgezeichnet: 22.–23. Mai 2026, aktualisiert: 23. Mai 2026  
Entwickelt mit: Claude Sonnet 4.6 (Claude Code)

---

## Projektübersicht

Eine interaktive Reisekarte als Single-Page-App (`index.html`).  
Backend: **Supabase** (PostgreSQL + Auth + Storage)  
Hosting: **GitHub Pages** / Netlify  
Repository: https://github.com/kagesuraa/reisetagebuch

---

## Entwicklungsverlauf

### Phase 1 — Grundgerüst (Firebase)
- Leaflet.js Weltkarte mit OpenStreetMap-Tiles
- Firebase Firestore als erstes Backend
- Klick auf Karte → Seitenleiste öffnet sich
- Felder: Ortsname, Datum, Notizen
- Einträge werden in Firestore gespeichert und geladen
- Marker auf der Karte mit Popup

### Phase 2 — Features & UI-Verbesserungen
- **Foto-Upload**: Base64-Komprimierung via Canvas (max 900px, JPEG 78%)
- **Statistik-Leiste**: Besuchte Orte / Fotos-Zähler
- **Responsive Design**: `100dvh`, `w-full sm:w-96` Sidebar
- **Karte begrenzt**: `maxBounds`, `noWrap: true`, `minZoom` dynamisch berechnet
- **Zoom-Controls** nach rechts unten verschoben (wie Google Maps)
- **Deutscher Tile-Server**: `tile.openstreetmap.de`

### Phase 3 — Migration zu Supabase
- Firebase komplett entfernt
- Supabase JS v2 eingebunden
- Tabelle `reise_eintraege` mit RLS-Policies
- CRUD-Operationen: `select`, `insert`, `delete`
- Anon-Key konfiguriert

**SQL-Schema:**
```sql
create table public.reise_eintraege (
  id            uuid primary key default gen_random_uuid(),
  lat           double precision not null,
  lng           double precision not null,
  location_name text not null,
  date          text,
  notes         text,
  image_url     text,    -- JSON-Array von Storage-URLs
  photo_url     text,    -- Legacy
  photo_base64  text,    -- Legacy
  created_at    timestamptz default now()
);
```

### Phase 4 — Erweiterte Kartenfeatures
- **Animierte Reiseroute** (Polyline): chronologisch nach Datum sortiert, Glüh-Effekt + animierte Striche
- **Route Toggle**: Ein/Aus-Schalter unten links
- **Pulsierender Preview-Pin** (Indigo) beim Klick auf die Karte
- **Nominatim Ortssuche** (oben mittig): Autovervollständigung, Karte springt zum Ort
- **Kartenstil-Wechsler**: Standard / Dark Mode (CartoDB) / Satellit (ESRI)
- **Linkes Panel** (Hover-Reveal): Statistiken, Filter, Trip-Cards

### Phase 5 — Linkes Panel & Dashboard
- **Statistik-Dashboard**: Gesamte Reisen / Nördlichster Punkt / Letztes Abenteuer
- **Filterleiste**: Textsuche (`.ilike()`) + Jahres-Dropdown
- **Trip-Cards**: Thumbnail, Ortsname, Datum, Notizen-Teaser
- **Klick auf Card**: `map.flyTo()` + Lightbox öffnet sich
- **Hover-Verhalten**: Panel erscheint nach Hover, bleibt 4 Sekunden sichtbar

### Phase 6 — Foto-System
- **Mehrfach-Upload**: `<input multiple>`, Thumbnail-Grid als Vorschau
- **Supabase Storage**: Bucket `trip-images`, Upload via `sb.storage.from('trip-images').upload()`
- **JSON-Array in `image_url`**: `JSON.stringify(["url1","url2",...])`
- **Transform-URLs**: `?width=400&resize=contain` für Popups, `?width=80` für Thumbnails
- **Backward-Compatibility**: `photo_url` und `photo_base64` werden als Fallback gelesen

### Phase 7 — Lightbox & Galerie
- **Lightbox Modal**: Ersetzt Leaflet-Popup, Fade+Scale-Animation
- **Foto-Karussell**: ‹ › Pfeile, Keyboard (←→ Escape), Foto-Zähler
- **Galerie-Modus**: Cinematic Dark-Mode, Masonry-Grid (3 Spalten), `allEntries`-Array
- **Galerie-Tabs**: Alle / ❤ Favoriten
- **`galItemClick`**: Öffnet Lightbox beim richtigen Foto-Index

### Phase 8 — Benutzerprofil & Favoriten
- **Profil**: Editierbarer Name, deterministische Avatar-Farbe, localStorage
- **Favoriten**: Heart-Toggle auf Trip-Cards, localStorage `reise_favorites`
- **Tabs**: Alle / Favoriten im linken Panel und in der Galerie

### Phase 9 — Ortsuche im Formular & GPS
- **Autocomplete im Formular**: Nominatim-API mit 380ms Debounce
- **GPS-Button**: `navigator.geolocation`, Reverse-Geocoding für Ortsname
- **Koordinaten** werden automatisch in `pendingLat`/`pendingLng` übernommen

### Phase 10 — Sprache & UI-Redesign
- **DE/EN Sprachumschalter**: vollständiges `tr`-Objekt, `t(key)`-Funktion, `applyLang()`
- **Sprache in localStorage** gespeichert
- **Apple-inspiriertes Redesign**: Inter-Font, stone/amber Palette, keine Gradienten
- **Orange zurück**: Gradienten, Buttons, Tabs alles orange
- **Linkes Panel & Sidebar**: `bg-orange-50` Hintergrund

### Phase 11 — Authentifizierung
- **Supabase Auth**: Email + Passwort
- **Register/Login**: `sb.auth.signUp()` / `sb.auth.signInWithPassword()`
- **Session-Persistenz**: `sb.auth.getSession()` beim Start
- **Logout**: Session löschen, Karte leeren, Auth-Form anzeigen
- **Benutzerfreundliche Fehlermeldungen**: Rate-Limit, falsche Credentials, etc.

### Phase 12 — Homepage & finaler Flow
- **Cinematic Hero**: Fullscreen Bildslider (5 Unsplash-Fotos, 5s Intervall), Dot-Navigation
- **Animierter Text**: Float-Up-Effekt für Headline, Subtitle, Button
- **"Start Your Journey"** Button: Fade-Out (0.8s), dann Karte + linkes Panel mit Auth-Form
- **Bereits eingeloggt**: Homepage wird übersprungen, direkt zur Karte
- **Auth im linken Panel**: `panel-auth-section` / `panel-main-section` Toggle

### Phase 13 — Mobile-Optimierung
- **Bottom Navigation**: 4 Tabs (Reisen, Galerie, Pinnwand, Route) + zentraler + FAB-Button
- **Bottom-Sheet Sidebar**: Formular schiebt sich von unten hoch auf Mobile/Tablet
- **Swipe-Gesten**: Sidebar schließen per Wischgeste nach unten, Panel per Wischgeste nach links
- **GitHub Pages Fix**: `index.html`-Redirect, `.nojekyll`-Datei gegen Jekyll-Build

### Phase 14 — Bild-Editor & KI-Formatierer
- **Cropper.js**: In-Browser Zuschneiden jedes Fotos vor dem Upload (Seitenverhältnis frei, Drehen)
- **KI-Formatierer** (Button im Notizen-Feld):
  - Zuerst über Supabase Edge Function (Deno, Anthropic API) — scheiterte an CORS/Adblocker
  - Dann direkter Aufruf der Anthropic API — ebenfalls geblockt
  - Lösung: **Google Gemini API** (kostenlos, CORS-freundlich, kein Backend nötig)
  - **Auto-Discovery**: `GET /v1beta/models` liefert alle verfügbaren Modelle → jedes proben bis eines antwortet → funktionierendes Modell in `localStorage('reise_gemini_model')` gecacht
  - API-Key wird einmalig eingegeben und in `localStorage('reise_gemini_key')` gespeichert

### Phase 15 — Pinnwand & Statistik-Diagramm
- **Pinnwand-Modus**: Pinterest-ähnliches CSS-Grid aller Einträge mit Fotos
  - Hover-Zoom, Foto-Zähler-Badge, Klick öffnet Lightbox
  - Selbe `opacity-0 pointer-events-none` / `.open`-Pattern wie Galerie
- **Chart.js Aktivitätsdiagramm**: Balkendiagramm im Statistik-Panel
  - Monat/Jahr-Umschalter
  - Orange-500 Farben, kein Gitternetz, responsive

### Phase 16 — Sprach-Features
- **Speech-to-Text**: Mikrofon-Button im Notizen-Feld
  - Web Speech API (`webkitSpeechRecognition`), `lang='de-DE'`, `continuous=true`
  - Echtzeit-Transkription: Interim-Text grau, Final-Text schwarz
  - Zweiter Klick stoppt die Aufnahme
- **Sprachnotiz-Aufnahme**: Separater Aufnahme-Button — ganzen Sprachmemo aufnehmen
  - `MediaRecorder` API für Aufnahme als WebM/OGG-Blob
  - **IndexedDB** (`reise_audio`, Store `rec`) für lokale Speicherung — kein Backend nötig
  - Aufnahme an Eintrag gebunden (Key = Supabase Entry ID)
  - In der Lightbox abspielbar mit `<audio>`-Element + orangem Player-Panel

### Phase 17 — Video-Upload
- **Video-Dateiauswahl**: `accept="image/*,video/*"` am File-Input
- **Upload**: Videos in denselben `trip-images` Supabase-Bucket — kein Backend-Change
- **`isVideoUrl(url)`**: Erkennt `.mp4`, `.webm`, `.mov`, `.avi`, `.mkv`, `.ogv` per Regex
- **`toDisplayUrl()`**: Überspringt Supabase Image-Transform-Parameter für Videos
- **Thumbnail-Grid**: Video-Vorschau mit ▶-Play-Icon-Overlay
- **Video-Vorschau-Modal**: Klick auf Thumbnail vor dem Speichern → Vollbild-Modal mit nativen Controls
- **Lightbox**: `<img>` und `<video>` Element koexistieren, werden per `classList.add('hidden')` umgeschaltet
- **Galerie & Pinnwand**: Rendern `<video>` statt `<img>` für Video-URLs
- **Eintragsliste** (linkes Panel): Video-Einträge zeigen dunkle Thumbnail-Kachel mit ▶ statt kaputtem Bild-Icon

### Phase 18 — 5 Major Features
**1. Einträge bearbeiten**
- Stift-Button in der Lightbox (Footer, neben Löschen)
- `openEditForm(entry)`: Füllt alle Felder vor, setzt `editingId`, zeigt bestehende Fotos als „gespeichert"-Kacheln
- Save-Handler erkennt `editingId !== null` → `UPDATE` statt `INSERT`
- Nach dem Update: Marker erneuert, `entries`/`allEntries` aktualisiert
- Karte-Klick während Edit-Modus: bricht Edit sauber ab (Bug-Fix)

**2. PWA / Installierbar**
- `manifest.json`: Name, Icons (SVG Data-URI), theme-color orange
- `sw.js`: Service Worker mit Offline-Cache für HTML + CDN-Assets
- iOS Meta-Tags: `apple-mobile-web-app-capable`, Status-Bar-Style
- App auf Homescreen installierbar (Chrome → „Zum Startbildschirm")

**3. PDF-Export**
- Download-Button neben „Statistiken" im Panel
- Rendert alle Einträge als Karten (Foto + Ort + Datum + Notizen) in `#print-area`
- `window.print()` + `@media print` CSS → Druckdialog → Als PDF speichern

**4. Jahrestags-Erinnerungen**
- Beim Laden: Check ob Monat+Tag eines Eintrags = heute UND ≥ 1 Jahr alt
- Zeigt dismissibles Banner oben: „Vor 2 Jahren warst du in Tokio!"
- Wegklicken speichert `dismissed`-State in `localStorage` (pro Tag)

**5. Marker-Clustering**
- `Leaflet.markercluster@1.5.3` via CDN
- Orange Cluster-Bubbles mit Anzahl, fächern beim Reinzoomen auf
- `clusterGroup.addLayer(marker)` statt `marker.addTo(map)`

### Phase 19 — Bugfixes & Stabilität
- **Tile-Server**: Wechsel von `tile.openstreetmap.de` (unzuverlässig) auf `{a|b|c}.tile.openstreetmap.org` mit Subdomain-Loadbalancing
- **Markercluster-Fehler**: `maxZoom: 19` am Map-Objekt gesetzt → behebt „Map has no maxZoom specified"
- **Edit-Bug**: Karte-Klick während offener Edit-Form überschrieb `editingId` nicht → Datenverlust-Risiko behoben
- **Video-Icon in Eintragsliste**: `<img>` für Video-URLs zeigte kaputtes Icon → ersetzt durch `<video preload="metadata">` mit ▶-Overlay

---

## Geplant / Nächstes Feature

### Phase 20 — Reise-Slideshow (in Arbeit)
- Vollbild-Slideshow aller Einträge mit Foto als Hintergrund
- Ortsname groß, Datum + Notizen eingeblendet
- Auto-Advance alle 4–5 Sekunden, Pause/Play, Pfeiltasten

---

## Technischer Stack

| Komponente | Technologie |
|---|---|
| Frontend | Vanilla HTML/JS, Tailwind CSS (CDN) |
| Karte | Leaflet.js 1.9.4 |
| Backend | Supabase (PostgreSQL) |
| Auth | Supabase Auth (Email/Password) |
| Storage | Supabase Storage (Bucket: `trip-images`) |
| Fonts | Inter (Google Fonts) |
| Geocoding | Nominatim (OpenStreetMap) |
| Tile-Server | OSM CDN (a/b/c.tile.openstreetmap.org) / CartoDB / ESRI |
| KI | Google Gemini API (kostenlos, Auto-Discovery) |
| Diagramme | Chart.js (CDN) |
| Bild-Editor | Cropper.js 1.6.2 (CDN) |
| Marker-Clustering | Leaflet.markercluster 1.5.3 (CDN) |
| Audio-Speicher | IndexedDB (Browser-nativ) |
| PWA | Web App Manifest + Service Worker |
| Hosting | GitHub Pages |
| Versionierung | Git + GitHub |

---

## Wichtige IDs (HTML-Elemente)

```
#left-panel          — Linkes Hover-Panel
#panel-auth-section  — Login/Register Form (nicht eingeloggt)
#panel-main-section  — Dashboard + Cards (eingeloggt)
#panel-logo-row      — Logo-Zeile (nicht eingeloggt)
#panel-profile-row   — Profil-Zeile (eingeloggt)
#sidebar             — Rechte Seitenleiste (neuer Eintrag)
#lightbox            — Foto-Lightbox Modal
#gallery             — Galerie-Overlay
#homepage            — Landing Page (Hero)
#auth-overlay        — Nicht mehr verwendet (hidden)
#map                 — Leaflet-Karte
```

---

## Supabase-Konfiguration

```
URL:  https://zjykhnebeyqmonhgvlja.supabase.co
Tabelle: reise_eintraege
Storage: trip-images (public)
Auth: Email/Password, Confirm email = OFF
```

**RLS-Policies:**
```sql
create policy "public read"   on public.reise_eintraege for select using (true);
create policy "public insert" on public.reise_eintraege for insert with check (true);
create policy "public delete" on public.reise_eintraege for delete using (true);
```

---

## Git-Commits (Chronologie)

1. Reisetagebuch Grundgerüst (Firebase)
2. Rename to index.html for Netlify
3. Responsive map: dynamic minZoom
4. Switch to German OSM tile server
5. Add animated travel route polyline with toggle
6. Add Nominatim location search
7. Add pulsing indigo preview pin
8. Add entry filter bar and migrate photos to Supabase Storage
9. Replace popup with fullscreen lightbox modal
10. Add left panel, tile switcher and stats dashboard
11. Multi-photo upload with carousel lightbox
12. Left panel clickable over lightbox, satellite tile
13. Card click: fly to location and open lightbox
14. Add Nominatim autocomplete to entry form
15. Add GPS location button to entry form
16. Add user profile, gallery mode and favorites
17. Fix gallery: use allEntries, smaller images
18. Left panel: hover to reveal, auto-hide
19. Left panel stays visible 4s after mouse leave
20. Apple-inspired UI redesign with warm stone palette
21. Add DE/EN language switcher with full i18n
22. Revert colour scheme back to orange
23. Left panel and sidebar: orange-50 background
24. Add Supabase Auth: register, login, logout
25. Add cinematic homepage with hero slider
26. Homepage: hero only + login/register in left panel
27. Responsive layout for phones and tablets
28. Add mobile bottom nav, swipe gestures, bottom-sheet sidebar
29. Fix mobile nav: route toggle
30. Add index.html redirect + .nojekyll for GitHub Pages
31. Add in-browser image editor with Cropper.js
32. Add AI notes formatter (Claude Haiku → Gemini Flash)
33. KI-Formatierer: Gemini auto-discovery + model caching
34. Add Pinnwand view: Pinterest-style photo grid
35. Add Chart.js activity bar chart to statistics panel
36. Add Speech-to-Text mic button for notes textarea
37. Add voice memo recording with IndexedDB + lightbox playback
38. Add video upload support for travel entries
39. Add video preview modal before saving entry
40. Fix broken image icon for video entries in left panel list
41. Add 5 major features: edit, PWA, PDF export, anniversaries, clustering
42. Fix edit-mode data corruption on accidental map click
43. Fix map tiles not loading (tile server + maxZoom)

---

*Generiert mit Claude Code (claude-sonnet-4-6)*
