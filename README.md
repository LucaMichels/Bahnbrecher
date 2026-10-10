# Bahnbrecher – Vereins-App (Testversion)

Eigenständige Web-App für den Kegelverein Bahnbrecher. Läuft ohne Server im Browser
und lässt sich auf dem Handy als App auf den Home-Bildschirm legen.

## Testen

- Demo-Login: `bahnbrecher@beispiel.de` / `kegeln2026`
- Persönliche Demo-PIN: `1111` (Luca M., Oliver, Marvin, Nils, Luca S., Felix, Luis)
- Ohne PIN (Erstanmeldung): Niklas, Matthias, Julian, Davin
- Admin-PIN: `1234`

## Wichtig

- Daten werden nur auf dem jeweiligen Handy gespeichert (localStorage).
  Andere Testhandys sehen sie nicht.
- Demo-Daten zurücksetzen: Adresse mit `?reset` am Ende öffnen.

## Dateien

- `index.html` – die App
- `runtime.js` – rendert die Oberfläche
- `vendor/` – React 18.3.1
- `manifest.webmanifest`, `icons/` – App-Symbol und Home-Bildschirm-Einstellungen
