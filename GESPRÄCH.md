# Reisetagebuch — Entwicklungsprotokoll

Aufgezeichnet: 22.–23. Mai 2026  
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
| Tile-Server | OSM DE / CartoDB / ESRI |
| Hosting | GitHub Pages / Netlify |
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

---

*Generiert mit Claude Code (claude-sonnet-4-6)*
