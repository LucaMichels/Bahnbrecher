-- Bahnbrecher – Startdaten (einmalig nach schema.sql im SQL Editor ausführen)
-- Legt den Verein mit Mitgliedern und Strafenkatalog an und zeigt am Ende die Einladungslinks.
do $$
declare c uuid;
begin
  insert into clubs (name, place, beitrag_std) values ('Bahnbrecher', 'Zur Schanze, Büren', 15) returning id into c;
  insert into members (club_id, name, full_name, role, role_short, color, is_admin, sort) values
    (c, 'Niklas', 'Niklas Rücker', '2. Vorsitzender', '2. Vorsitz', '#E8A33D', true, 0),
    (c, 'Luca M.', 'Luca Michels', '1. Vorsitzender', '1. Vorsitz', '#7FB7EC', true, 1),
    (c, 'Oliver', 'Oliver Koch', 'Kassenwart', 'Kasse', '#86CC94', false, 2),
    (c, 'Marvin', 'Marvin Schweins', 'Schriftführer', 'Schriftführer', '#EE9A90', false, 3),
    (c, 'Nils', 'Nils Müller', 'Spaßwart, Schanzenbeauftragter', 'Spaßwart', '#C3B1E6', false, 4),
    (c, 'Luca S.', 'Luca Sprenger', 'Spaßwart, Strafenbeauftragter', 'Strafen', '#6FCBC0', false, 5),
    (c, 'Felix', 'Felix Böing', 'Strafenbeauftragter', 'Strafen', '#F2A0C4', false, 6),
    (c, 'Luis', 'Luis Althaus', 'Einschenker', 'Einschenker', '#F3C77A', false, 7),
    (c, 'Matthias', 'Matthias Hönig', '', '', '#A9D18E', false, 8),
    (c, 'Julian', 'Julian Müller', '', '', '#F0B48A', false, 9),
    (c, 'Davin', 'Davin Steinhauer', '', '', '#9FC3E8', false, 10);
  insert into rules (club_id, name, amount, cat, def, others, round, adopted, active, sort) values
    (c, 'Unabgemeldet', 15, 'Pünktlichkeit & Teilnahme', 'Abwesenheit ohne oder mit zu später Abmeldung (< 24 h) oder unzureichender Grund', false, false, true, true, 0),
    (c, 'Zu spät', 5, 'Pünktlichkeit & Teilnahme', 'Ohne Ankündigung nach 19:05 Uhr angekommen', false, false, true, true, 1),
    (c, 'Kegelshirt', 20, 'Pünktlichkeit & Teilnahme', 'Das Kegelshirt nicht getragen', false, false, true, true, 2),
    (c, 'Aus Bahn werfen', 5, 'Auf der Bahn', 'Kugel verlässt die Bahn', false, false, true, true, 3),
    (c, 'Band berühren', 1, 'Auf der Bahn', 'Berührung des Bandes mit Körper oder Kugel', false, false, true, true, 4),
    (c, 'Kugel rollt zurück', 5, 'Auf der Bahn', 'Kugel rollt eigenständig zurück über die Bahn', false, false, true, true, 5),
    (c, 'Kugel rollt durch', 1, 'Auf der Bahn', 'Kugel läuft ohne Treffer durch, alle anderen zahlen', true, false, true, true, 6),
    (c, 'Kugel wird eingeholt', 2, 'Auf der Bahn', 'Gelingt es, zahlt der Werfer der langsamen Kugel, sonst der der zweiten', false, false, true, true, 7),
    (c, 'Kranz', 5, 'Auf der Bahn', 'Nur der Kegel in der Mitte bleibt stehen', false, false, true, true, 8),
    (c, 'Spiel verloren', 2, 'Auf der Bahn', 'Spiel wird von einer Person oder einem Team verloren', false, false, true, true, 9),
    (c, 'Lustwurf', 5, 'Auf der Bahn', 'Unnötiger oder nicht autorisierter Wurf (nur bei Spiel)', false, false, true, true, 10),
    (c, 'Alle Neune', 1, 'Auf der Bahn', 'Alle 9 Kegel abgeräumt, alle anderen zahlen', true, false, true, true, 11),
    (c, 'Handynutzung', 5, 'Verhalten & Regeln', 'Übermäßiges Beschäftigen mit dem Handy (nach Ermessen der Gruppe)', false, false, true, true, 12),
    (c, 'Nicht trinken', 10, 'Verhalten & Regeln', 'Nur nichtalkoholische Getränke (Ausnahme vorab schriftlich bei einem Strafenbeauftragten)', false, false, true, true, 13),
    (c, 'Alkohol verdunstet', 2, 'Verhalten & Regeln', 'Zu langsames Trinken (nach Ermessen der Gruppe)', false, false, true, true, 14),
    (c, 'Getränk umschmeißen', 5, 'Verhalten & Regeln', 'Ein Getränk wird umgeworfen – egal wessen', false, false, true, true, 15),
    (c, 'Rauchen beim Kegeln', 20, 'Verhalten & Regeln', 'Zigarette auf der Bahn', false, false, true, true, 16),
    (c, 'Geburtstag', 0, 'Verhalten & Regeln', 'Wer am Kegelabend Geburtstag hat, gibt eine Runde aus', false, true, true, true, 17),
    (c, 'Gastkegler', 10, 'Verhalten & Regeln', 'Gäste zahlen symbolisch für die Teilnahme', false, false, true, true, 18),
    (c, 'Pudel (Rinne)', 0.5, 'Auf der Bahn', 'Kugel landet in der Rinne', false, false, false, false, 19),
    (c, 'Übertreten', 0.5, 'Auf der Bahn', 'Beim Wurf über die Linie getreten', false, false, false, false, 20),
    (c, 'Wurf verpasst', 1, 'Verhalten & Regeln', 'Nicht da, wenn man an der Reihe ist', false, false, false, false, 21);
  insert into expense_groups (club_id, name, foreign_cur, rate) values (c, 'Kegelfahrt Mai 2027', 'CZK', 25);
end $$;

-- Einladungslinks: jedem Mitglied seinen eigenen Link schicken
select m.name, 'https://lucamichels.github.io/Bahnbrecher/?join=' || m.invite_token as einladungslink
from members m join clubs c on c.id = m.club_id where c.name = 'Bahnbrecher' order by m.sort;
