# Backend (Supabase)

Datenbank, Login und Live-Updates für die Vereins-App. Mehrvereinsfähig: Jeder Verein sieht nur seine eigenen Daten,
die Rechte (Strafen erfassen, Kasse usw.) prüft die Datenbank selbst.

## Einrichtung (einmalig)

1. Auf [supabase.com](https://supabase.com) anmelden (geht mit dem GitHub-Konto) und ein Projekt anlegen:
   - Name: `bahnbrecher`
   - Region: **Central EU (Frankfurt)**
   - Datenbank-Passwort: sicher im Passwortmanager ablegen (wird für die App nicht gebraucht)
2. **SQL Editor** → „New query“ → Inhalt von `schema.sql` einfügen → **Run**.
3. Neue Query → Inhalt von `seed_bahnbrecher.sql` einfügen → **Run**, danach `migration_02_vereinslogin.sql`.
4. **Authentication → URL Configuration**:
   - Site URL: `https://lucamichels.github.io/Bahnbrecher/`
   - Redirect URLs: `https://lucamichels.github.io/Bahnbrecher/**` und `http://localhost:8770/**`
5. **Project Settings → API**: „Project URL“ und den **publishable/anon key** in die App eintragen.
   Diese beiden Werte sind öffentlich gedacht. Den **secret/service_role key niemals** in die App oder ins Repo.

## Anmeldung in der App

- **Ein Vereins-Login pro Verein** (E-Mail + Passwort), angelegt unter Authentication → Users → Add user
  mit „Auto confirm user“. Es werden keine Mails verschickt.
- Verknüpfen mit dem Verein (einmalig im SQL Editor, siehe Ende von `migration_02_vereinslogin.sql`).
- Danach wählt jedes Mitglied in der App sein Profil und legt beim ersten Mal eine 4-stellige PIN fest.
  PINs und Admin-PIN liegen nur als Hash in der Datenbank und gelten auf jedem Handy.
- Die Admin-PIN wird beim ersten Admin-Zugriff festgelegt. Zurücksetzen: `update clubs set admin_pin_hash = null`.
- Die Datenbank trennt die Vereine. Welches Mitglied was darf, prüft beim Vereins-Login die App.

## Rechte

| Recht | Wer |
|---|---|
| Mitglieder, Termine, Ausgaben-Gruppen, eigene Party-Karten verwalten | Admins |
| Strafen erfassen / alle sehen / löschen / als bezahlt markieren | laut Schaltern im Verein (`clubs.rights`) |
| Als bezahlt markieren | zusätzlich immer Kassenwart und Strafenbeauftragte |
| Abmeldegründe anderer sehen | Schalter `seeReasons`; Zu- und Absagen selbst sehen alle |
| Vereinskonto sehen / Gaststätte eintragen | `seeKonto` / `kasse` |
| Ausgabe aus der Kegelkasse | `expenses` **und** `kasse` |

## Hinweise

- Der kostenlose Supabase-Tarif verschickt nur wenige Login-Mails pro Stunde. Für den Start reicht das,
  später eigenen Mailversand (SMTP) eintragen.
- Datenschutz: Unter Supabase → Organization → Legal Documents den Auftragsverarbeitungsvertrag (DPA) abschließen.
