# Backend (Supabase)

Datenbank, Login und Live-Updates für die Vereins-App. Mehrvereinsfähig: Jeder Verein sieht nur seine eigenen Daten,
die Rechte (Strafen erfassen, Kasse usw.) prüft die Datenbank selbst.

## Einrichtung (einmalig)

1. Auf [supabase.com](https://supabase.com) anmelden (geht mit dem GitHub-Konto) und ein Projekt anlegen:
   - Name: `bahnbrecher`
   - Region: **Central EU (Frankfurt)**
   - Datenbank-Passwort: sicher im Passwortmanager ablegen (wird für die App nicht gebraucht)
2. **SQL Editor** → „New query“ → Inhalt von `schema.sql` einfügen → **Run**.
3. Neue Query → Inhalt von `seed_bahnbrecher.sql` einfügen → **Run**. Am Ende erscheinen die Einladungslinks.
4. **Authentication → URL Configuration**:
   - Site URL: `https://lucamichels.github.io/Bahnbrecher/`
   - Redirect URLs: `https://lucamichels.github.io/Bahnbrecher/**` und `http://localhost:8770/**`
5. **Project Settings → API**: „Project URL“ und den **publishable/anon key** in die App eintragen.
   Diese beiden Werte sind öffentlich gedacht. Den **secret/service_role key niemals** in die App oder ins Repo.

## Anmeldung in der App

- Mitglieder melden sich per E-Mail-Code an (kein Passwort).
- Neue Mitglieder öffnen ihren persönlichen Einladungslink (`?join=…`), melden sich an und sind damit ihrem
  Eintrag im Verein zugeordnet. Ein Link funktioniert nur für eine Person.
- Admins können einen Link erneuern (`renew_invite`), z. B. bei Handywechsel; der alte wird ungültig.

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
