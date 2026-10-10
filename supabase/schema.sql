-- Bahnbrecher – Datenbankschema für Supabase (Postgres)
-- Mehrvereinsfähig: jede Tabelle hängt an club_id, die Rechte prüft die Datenbank (Row Level Security).
-- Einmalig im Supabase-Dashboard unter "SQL Editor" ausführen.

create extension if not exists pgcrypto;

-- =========================================================
-- Tabellen
-- =========================================================

create table public.clubs (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  place         text not null default '',
  -- Schalter aus der Rechteverwaltung, z. B. {"fines": true, "seeKonto": true}
  rights        jsonb not null default '{"fines": true, "seeAllFines": true, "seeReasons": true, "editFines": false,
                  "markPaid": false, "editRules": false, "attendance": false, "expenses": true, "seeKonto": true, "kasse": false}',
  beitrag_std   numeric(10,2) not null default 15,
  anchor_date   date,                       -- letzter Kontoabgleich
  anchor_amount numeric(10,2) not null default 0,
  anchor_months int not null default 0,     -- Monatsbeiträge seit Abgleich
  created_at    timestamptz not null default now()
);

create table public.members (
  id           uuid primary key default gen_random_uuid(),
  club_id      uuid not null references public.clubs on delete cascade,
  user_id      uuid references auth.users on delete set null,  -- leer, bis die Person ihre Einladung annimmt
  name         text not null,              -- Kurzname, z. B. "Luca M."
  full_name    text not null default '',
  role         text not null default '',   -- Amt, z. B. "Kassenwart"
  role_short   text not null default '',
  color        text not null default '#E8A33D',
  beitrag      numeric(10,2),              -- eigener Monatsbeitrag, leer = Standard
  is_admin     boolean not null default false,
  active       boolean not null default true,
  invite_token uuid not null default gen_random_uuid() unique,
  sort         int not null default 0,
  created_at   timestamptz not null default now(),
  unique (club_id, user_id)
);

create table public.rules (
  id       uuid primary key default gen_random_uuid(),
  club_id  uuid not null references public.clubs on delete cascade,
  name     text not null,
  amount   numeric(10,2) not null default 0,
  cat      text not null default 'Eigene',
  def      text not null default '',
  others   boolean not null default false, -- alle anderen zahlen (z. B. Alle Neune)
  round    boolean not null default false, -- gibt eine Runde aus
  adopted  boolean not null default true,  -- per Beschluss übernommen
  active   boolean not null default true,
  sort     int not null default 0
);

create table public.fines (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs on delete cascade,
  member_id  uuid not null references public.members on delete cascade,
  rule_id    uuid references public.rules on delete set null,
  name       text not null,
  amount     numeric(10,2) not null default 0,
  round      boolean not null default false,
  date       date not null default current_date,
  paid       boolean not null default false,
  paid_on    date,
  created_by uuid references public.members on delete set null,
  created_at timestamptz not null default now()
);

create table public.events (
  id             uuid primary key default gen_random_uuid(),
  club_id        uuid not null references public.clubs on delete cascade,
  series_id      uuid,                     -- gemeinsame ID bei Serienterminen
  date           date not null,
  time           time not null default '19:00',
  title          text not null default 'Kegelabend',
  place          text not null default '',
  deadline_hours int not null default 24,  -- Abmeldefrist in Stunden, 0 = keine
  created_at     timestamptz not null default now()
);

create table public.rsvps (
  event_id  uuid not null references public.events on delete cascade,
  member_id uuid not null references public.members on delete cascade,
  club_id   uuid not null references public.clubs on delete cascade,
  status    text not null check (status in ('yes', 'no')),
  reason    text not null default '',
  updated_at timestamptz not null default now(),
  primary key (event_id, member_id)
);

create table public.attendance (
  event_id  uuid not null references public.events on delete cascade,
  member_id uuid not null references public.members on delete cascade,
  club_id   uuid not null references public.clubs on delete cascade,
  status    text not null,                 -- z. B. 'da', 'spaet', 'fehlt'
  primary key (event_id, member_id)
);

-- Zahlungen an die Gaststätte (pro Kegelabend vom Vereinskonto)
create table public.gastro (
  id       uuid primary key default gen_random_uuid(),
  club_id  uuid not null references public.clubs on delete cascade,
  event_id uuid references public.events on delete set null,
  date     date not null default current_date,
  amount   numeric(10,2) not null default 0
);

-- Ausgaben-Gruppen, z. B. "Kegelfahrt Mai 2027"
create table public.expense_groups (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs on delete cascade,
  name       text not null,
  foreign_cur text not null default 'CZK',
  rate       numeric(12,4) not null default 25,  -- 1 EUR = rate Fremdwährung
  created_at timestamptz not null default now()
);

create table public.expenses (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs on delete cascade,
  group_id   uuid not null references public.expense_groups on delete cascade,
  description text not null,
  amount     numeric(12,2) not null,
  cur        text not null default 'EUR',
  payer_id   uuid references public.members on delete set null,  -- leer, wenn die Kegelkasse zahlt
  paid_by_kasse boolean not null default false,
  among      uuid[] not null default '{}',  -- Mitglieder, auf die aufgeteilt wird
  date       date not null default current_date,
  created_by uuid references public.members on delete set null,
  created_at timestamptz not null default now(),
  check (paid_by_kasse or payer_id is not null)
);

-- erledigte Ausgleichszahlungen ("Als bezahlt markieren")
create table public.settlements (
  club_id  uuid not null references public.clubs on delete cascade,
  group_id uuid not null references public.expense_groups on delete cascade,
  key      text not null,                  -- von→an:betrag
  primary key (group_id, key)
);

-- eigene Party-Karten eines Vereins (die Standardkarten stehen in der App)
create table public.party_cards (
  id      uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs on delete cascade,
  kind    text not null,
  text    text not null,
  alt     text not null,
  bahn    boolean not null default false
);

create index on public.members (user_id);
create index on public.fines (club_id, date);
create index on public.events (club_id, date);
create index on public.expenses (group_id);

-- =========================================================
-- Hilfsfunktionen für die Rechte (security definer, damit die Regeln nicht rekursiv werden)
-- =========================================================

create or replace function public.is_member(c uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from members where club_id = c and user_id = auth.uid() and active);
$$;

create or replace function public.my_member_id(c uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select id from members where club_id = c and user_id = auth.uid() and active limit 1;
$$;

create or replace function public.is_admin(c uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from members where club_id = c and user_id = auth.uid() and active and is_admin);
$$;

-- Recht laut Schalter, Admin hat alles; Kassenwart und Strafenbeauftragte dürfen immer als bezahlt markieren
create or replace function public.has_right(c uuid, k text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from members m join clubs cl on cl.id = m.club_id
    where m.club_id = c and m.user_id = auth.uid() and m.active
      and (m.is_admin
           or coalesce((cl.rights ->> k)::boolean, false)
           or (k = 'markPaid' and (m.role ilike '%Kassenwart%' or m.role ilike '%Strafenbeauftragt%')))
  );
$$;

-- =========================================================
-- Aktionen
-- =========================================================

-- Neuen Verein anlegen; wer ihn anlegt, wird Admin
create or replace function public.create_club(club_name text, club_place text, my_name text, my_full_name text default '')
returns uuid language plpgsql security definer set search_path = public as $$
declare c uuid;
begin
  if auth.uid() is null then raise exception 'Nicht angemeldet'; end if;
  insert into clubs (name, place) values (club_name, club_place) returning id into c;
  insert into members (club_id, user_id, name, full_name, is_admin) values (c, auth.uid(), my_name, my_full_name, true);
  return c;
end $$;

-- Einladung annehmen: verknüpft den angemeldeten Account mit dem vorbereiteten Mitglied
create or replace function public.claim_member(token uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare m members;
begin
  if auth.uid() is null then raise exception 'Nicht angemeldet'; end if;
  select * into m from members where invite_token = token and active;
  if not found then raise exception 'Einladung ungültig'; end if;
  if m.user_id is not null and m.user_id <> auth.uid() then raise exception 'Einladung wurde schon verwendet'; end if;
  if exists (select 1 from members where club_id = m.club_id and user_id = auth.uid() and id <> m.id) then
    raise exception 'Du bist in diesem Verein schon angemeldet';
  end if;
  update members set user_id = auth.uid() where id = m.id;
  return m.club_id;
end $$;

-- Admin erzeugt einen neuen Einladungslink (alter wird ungültig)
create or replace function public.renew_invite(member uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare c uuid; t uuid := gen_random_uuid();
begin
  select club_id into c from members where id = member;
  if not public.is_admin(c) then raise exception 'Nur für Admins'; end if;
  update members set invite_token = t, user_id = null where id = member;
  return t;
end $$;

-- Zu- und Absagen ohne Gründe für alle Mitglieder; Gründe nur über die Tabelle (Recht seeReasons)
create view public.rsvp_status as
  select event_id, member_id, club_id, status, updated_at from public.rsvps where public.is_member(club_id);

-- Wer nur als bezahlt markieren darf, darf an einer Strafe sonst nichts ändern
create or replace function public.fines_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not public.has_right(old.club_id, 'editFines') and
     (new.club_id, new.member_id, new.rule_id, new.name, new.amount, new.round, new.date)
       is distinct from (old.club_id, old.member_id, old.rule_id, old.name, old.amount, old.round, old.date) then
    raise exception 'Nur Zahlstatus darf geändert werden';
  end if;
  return new;
end $$;
create trigger fines_guard before update on public.fines for each row execute function public.fines_guard();

-- Zugriff über die API nur für angemeldete Nutzer; was sie sehen dürfen, regeln die Policies unten.
-- (Ausdrücklich, weil "Automatically expose new tables" im Projekt ausgeschaltet ist.)
revoke all on all tables in schema public from anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
revoke execute on all functions in schema public from anon, public;
grant execute on function public.is_member, public.my_member_id, public.is_admin, public.has_right to authenticated;

-- Das Einladungstoken sehen nur Admins
-- (Spaltenrechte statt Tabellenrecht: invite_token ist nicht lesbar, Abfragen müssen die Spalten nennen)
revoke select on public.members from anon, authenticated;
grant select (id, club_id, user_id, name, full_name, role, role_short, color, beitrag, is_admin, active, sort, created_at)
  on public.members to authenticated;
grant execute on function public.create_club, public.claim_member, public.renew_invite to authenticated;

-- Admins lesen Einladungstokens über diese Funktion
create or replace function public.invite_tokens(c uuid)
returns table (member_id uuid, name text, token uuid, claimed boolean)
language sql stable security definer set search_path = public as $$
  select id, name, invite_token, user_id is not null from members where club_id = c and public.is_admin(c) order by sort, name;
$$;
grant execute on function public.invite_tokens to authenticated;

-- =========================================================
-- Row Level Security
-- =========================================================

alter table public.clubs          enable row level security;
alter table public.members        enable row level security;
alter table public.rules          enable row level security;
alter table public.fines          enable row level security;
alter table public.events         enable row level security;
alter table public.rsvps          enable row level security;
alter table public.attendance     enable row level security;
alter table public.gastro         enable row level security;
alter table public.expense_groups enable row level security;
alter table public.expenses       enable row level security;
alter table public.settlements    enable row level security;
alter table public.party_cards    enable row level security;

-- Verein
create policy clubs_read   on public.clubs for select to authenticated using (is_member(id));
create policy clubs_update on public.clubs for update to authenticated using (is_admin(id)) with check (is_admin(id));
create policy clubs_delete on public.clubs for delete to authenticated using (is_admin(id));

-- Mitglieder: alle im Verein sehen sich, nur Admins pflegen
create policy members_read  on public.members for select to authenticated using (is_member(club_id));
create policy members_write on public.members for all    to authenticated using (is_admin(club_id)) with check (is_admin(club_id));

-- Strafregeln
create policy rules_read  on public.rules for select to authenticated using (is_member(club_id));
create policy rules_write on public.rules for all    to authenticated using (has_right(club_id, 'editRules')) with check (has_right(club_id, 'editRules'));

-- Strafen: eigene immer, alle mit seeAllFines
create policy fines_read   on public.fines for select to authenticated
  using (is_member(club_id) and (has_right(club_id, 'seeAllFines') or member_id = my_member_id(club_id)));
create policy fines_insert on public.fines for insert to authenticated with check (has_right(club_id, 'fines'));
create policy fines_update on public.fines for update to authenticated
  using (has_right(club_id, 'editFines') or has_right(club_id, 'markPaid'))
  with check (has_right(club_id, 'editFines') or has_right(club_id, 'markPaid'));
create policy fines_delete on public.fines for delete to authenticated using (has_right(club_id, 'editFines'));

-- Termine: alle sehen, Admins legen an
create policy events_read  on public.events for select to authenticated using (is_member(club_id));
create policy events_write on public.events for all    to authenticated using (is_admin(club_id)) with check (is_admin(club_id));

-- Zu-/Absagen: eigene schreiben; Gründe der anderen nur mit seeReasons
create policy rsvps_read  on public.rsvps for select to authenticated
  using (member_id = my_member_id(club_id) or has_right(club_id, 'seeReasons'));
create policy rsvps_write on public.rsvps for all to authenticated
  using (member_id = my_member_id(club_id)) with check (member_id = my_member_id(club_id));

-- Anwesenheit
create policy att_read  on public.attendance for select to authenticated using (is_member(club_id));
create policy att_write on public.attendance for all    to authenticated using (has_right(club_id, 'attendance')) with check (has_right(club_id, 'attendance'));

-- Gaststätte / Vereinskonto
create policy gastro_read  on public.gastro for select to authenticated using (has_right(club_id, 'seeKonto'));
create policy gastro_write on public.gastro for all    to authenticated using (has_right(club_id, 'kasse')) with check (has_right(club_id, 'kasse'));

-- Ausgaben: alle sehen; anlegen mit Recht expenses, aus der Kegelkasse nur mit Recht kasse
create policy eg_read  on public.expense_groups for select to authenticated using (is_member(club_id));
create policy eg_write on public.expense_groups for all    to authenticated using (is_admin(club_id)) with check (is_admin(club_id));
create policy exp_read   on public.expenses for select to authenticated using (is_member(club_id));
create policy exp_insert on public.expenses for insert to authenticated
  with check (has_right(club_id, 'expenses') and (not paid_by_kasse or has_right(club_id, 'kasse')));
create policy exp_change on public.expenses for update to authenticated
  using (created_by = my_member_id(club_id) or is_admin(club_id))
  with check ((created_by = my_member_id(club_id) or is_admin(club_id)) and (not paid_by_kasse or has_right(club_id, 'kasse')));
create policy exp_delete on public.expenses for delete to authenticated
  using (created_by = my_member_id(club_id) or is_admin(club_id));
create policy settle_read  on public.settlements for select to authenticated using (is_member(club_id));
create policy settle_write on public.settlements for all    to authenticated using (is_member(club_id)) with check (is_member(club_id));

-- Party-Karten
create policy cards_read  on public.party_cards for select to authenticated using (is_member(club_id));
create policy cards_write on public.party_cards for all    to authenticated using (is_admin(club_id)) with check (is_admin(club_id));

-- =========================================================
-- Live-Updates (Strafe am Tisch erscheint sofort auf allen Handys)
-- =========================================================
alter publication supabase_realtime add table public.fines, public.rsvps, public.attendance, public.events, public.expenses, public.settlements;
