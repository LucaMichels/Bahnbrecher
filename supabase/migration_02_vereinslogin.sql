-- Bahnbrecher – Vereins-Login statt Login pro Mitglied
-- Ein gemeinsamer Login pro Verein (E-Mail + Passwort, keine Mails nötig).
-- Danach wählt man in der App sein Profil und bestätigt mit seiner PIN.
-- Die Datenbank trennt die Vereine; welches Mitglied was darf, regelt die App.
-- Einmalig nach schema.sql im SQL Editor ausführen.

-- Welcher Login gehört zu welchem Verein
create table public.club_accounts (
  user_id    uuid primary key references auth.users on delete cascade,
  club_id    uuid not null references public.clubs on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.club_accounts enable row level security;
create policy club_accounts_own on public.club_accounts for select to authenticated using (user_id = auth.uid());
grant select on public.club_accounts to authenticated;

-- PINs (nur als Hash gespeichert, nicht lesbar)
alter table public.members add column pin_hash text;
alter table public.members add column has_pin boolean generated always as (pin_hash is not null) stored;
alter table public.clubs add column admin_pin_hash text;
alter table public.clubs add column has_admin_pin boolean generated always as (admin_pin_hash is not null) stored;

-- Spaltenrechte: Hashes weder lesen noch direkt schreiben
grant select (has_pin) on public.members to authenticated;
revoke update on public.members from authenticated;
grant update (name, full_name, role, role_short, color, beitrag, is_admin, active, sort) on public.members to authenticated;
revoke select, update on public.clubs from authenticated;
grant select (id, name, place, rights, beitrag_std, anchor_date, anchor_amount, anchor_months, created_at, has_admin_pin) on public.clubs to authenticated;
grant update (name, place, rights, beitrag_std, anchor_date, anchor_amount, anchor_months) on public.clubs to authenticated;

-- Rechte: der Vereins-Login zählt als Mitglied mit allen Rechten seines Vereins
create or replace function public.is_club_account(c uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from club_accounts where club_id = c and user_id = auth.uid());
$$;

create or replace function public.is_member(c uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from members where club_id = c and user_id = auth.uid() and active)
      or public.is_club_account(c);
$$;

create or replace function public.is_admin(c uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from members where club_id = c and user_id = auth.uid() and active and is_admin)
      or public.is_club_account(c);
$$;

create or replace function public.has_right(c uuid, k text) returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_club_account(c) or exists (
    select 1 from members m join clubs cl on cl.id = m.club_id
    where m.club_id = c and m.user_id = auth.uid() and m.active
      and (m.is_admin
           or coalesce((cl.rights ->> k)::boolean, false)
           or (k = 'markPaid' and (m.role ilike '%Kassenwart%' or m.role ilike '%Strafenbeauftragt%')))
  );
$$;

-- Zu-/Absagen: der Vereins-Login schreibt für das in der App gewählte Profil
drop policy rsvps_read on public.rsvps;
drop policy rsvps_write on public.rsvps;
create policy rsvps_read on public.rsvps for select to authenticated
  using (is_member(club_id) and (member_id = my_member_id(club_id) or has_right(club_id, 'seeReasons')));
create policy rsvps_write on public.rsvps for all to authenticated
  using (member_id = my_member_id(club_id) or is_club_account(club_id))
  with check (member_id = my_member_id(club_id) or is_club_account(club_id));

-- PIN prüfen / festlegen / zurücksetzen
create or replace function public.verify_pin(member uuid, pin text) returns boolean
language plpgsql stable security definer set search_path = public, extensions as $$
declare m members;
begin
  select * into m from members where id = member;
  if not found or not public.is_member(m.club_id) then return false; end if;
  return m.pin_hash is not null and m.pin_hash = crypt(pin, m.pin_hash);
end $$;

create or replace function public.set_pin(member uuid, pin text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare m members;
begin
  select * into m from members where id = member;
  if not found or not public.is_member(m.club_id) then raise exception 'Kein Zugriff'; end if;
  if pin !~ '^[0-9]{4}$' then raise exception 'Die PIN muss 4 Ziffern haben'; end if;
  if m.pin_hash is not null then raise exception 'Für dieses Profil gibt es schon eine PIN'; end if;
  update members set pin_hash = crypt(pin, gen_salt('bf')) where id = member;
end $$;

create or replace function public.reset_pin(member uuid) returns void
language plpgsql security definer set search_path = public as $$
declare c uuid;
begin
  select club_id into c from members where id = member;
  if not public.is_admin(c) then raise exception 'Nur für Admins'; end if;
  update members set pin_hash = null where id = member;
end $$;

-- Admin-PIN: 'ok', 'wrong' oder 'set' (noch keine vorhanden, eingegebene wird festgelegt)
create or replace function public.verify_admin_pin(c uuid, pin text) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare h text;
begin
  if not public.is_member(c) then return 'wrong'; end if;
  if pin !~ '^[0-9]{4}$' then return 'wrong'; end if;
  select admin_pin_hash into h from clubs where id = c;
  if h is null then
    update clubs set admin_pin_hash = crypt(pin, gen_salt('bf')) where id = c;
    return 'set';
  end if;
  return case when h = crypt(pin, h) then 'ok' else 'wrong' end;
end $$;

revoke execute on function public.is_club_account, public.verify_pin, public.set_pin, public.reset_pin, public.verify_admin_pin from public, anon;
grant execute on function public.is_club_account, public.verify_pin, public.set_pin, public.reset_pin, public.verify_admin_pin to authenticated;

-- Nach dem Anlegen des Vereins-Logins (Authentication → Users → Add user) verknüpfen, z. B.:
-- insert into club_accounts (user_id, club_id)
--   select u.id, c.id from auth.users u, clubs c where u.email = 'verein@beispiel.de' and c.name = 'Bahnbrecher';
