-- Run this once in Supabase: SQL Editor -> New query -> paste -> Run.

create table if not exists public.docs (
  collection text not null,
  id text not null,
  data jsonb not null default '{}'::jsonb,
  owner uuid default auth.uid(),
  updated_at timestamptz not null default now(),
  primary key (collection, id)
);

create table if not exists public.admins (email text primary key);

alter table public.docs enable row level security;
alter table public.admins enable row level security;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.admins
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

-- Admins can see their own row (so the page can tell who is an admin).
create policy "admins see themselves" on public.admins for select
  using (lower(email) = lower(coalesce(auth.jwt() ->> 'email', '')));

-- Everyone signed in (guests are signed in anonymously) can read.
create policy "signed in can read" on public.docs for select
  using (auth.uid() is not null);

-- Admins can do everything.
create policy "admins write everything" on public.docs for all
  using (public.is_admin()) with check (public.is_admin());

-- Guests can add bookings and change only their own bookings.
create policy "guests add bookings" on public.docs for insert
  with check (collection = 'bookings' and owner = auth.uid());
create policy "guests change own bookings" on public.docs for update
  using (collection = 'bookings' and owner = auth.uid())
  with check (collection = 'bookings' and owner = auth.uid());

-- Guests cannot confirm a booking, assign rooms, or take over someone else's booking.
create or replace function public.guard_docs() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.updated_at := now();
  if new.collection = 'bookings' and not public.is_admin() then
    if tg_op = 'INSERT' then
      new.owner := auth.uid();
      new.data := (new.data - 'slots' - 'status') || '{"status":"pending"}'::jsonb;
    else
      new.owner := old.owner;
      if coalesce(new.data ->> 'status', '') = 'confirmed'
         and coalesce(old.data ->> 'status', '') <> 'confirmed' then
        raise exception 'Only an admin can confirm a booking';
      end if;
      new.data := (new.data - 'slots') ||
        case when (old.data -> 'slots') is not null
             then jsonb_build_object('slots', old.data -> 'slots')
             else '{}'::jsonb end;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_docs on public.docs;
create trigger guard_docs before insert or update on public.docs
  for each row execute function public.guard_docs();

-- Live updates between phones.
alter publication supabase_realtime add table public.docs;


-- STEP: make yourself the admin. Replace the email below with YOUR email, then run everything.
insert into public.admins (email) values ('CHANGE-ME@example.com') on conflict do nothing;

-- Starting data copied from the claude.ai version (properties, teams, settings).
-- Bookings and payments are not copied (they were test entries).
insert into public.docs (collection, id, data) values
  ('properties', 'mv3vjt3axv8v', '{"amenities": ["-"], "desc": "Ameene Magu", "name": "Autha Inn", "phone": "76767676", "rooms": [{"id": "mv3w3vev005e", "name": "Double Room", "qty": 6, "rate": 500}], "type": "Guesthouse"}'::jsonb),
  ('teams', 't01', '{"academy": "Basheer Sports Academy", "age": "U10", "island": "HDh. Kulhudhuffushi", "label": "B"}'::jsonb),
  ('teams', 't02', '{"academy": "Basheer Sports Academy", "age": "U10", "island": "HDh. Kulhudhuffushi", "label": ""}'::jsonb),
  ('teams', 't03', '{"academy": "Basheer Sports Academy", "age": "U12", "island": "HDh. Kulhudhuffushi", "label": "A"}'::jsonb),
  ('teams', 't04', '{"academy": "Basheer Sports Academy", "age": "U12", "island": "HDh. Kulhudhuffushi", "label": "B"}'::jsonb),
  ('teams', 't05', '{"academy": "IMAGU Sports Academy", "age": "U10", "island": "Ha. Ihavandhoo", "label": ""}'::jsonb),
  ('teams', 't06', '{"academy": "IMAGU Sports Academy", "age": "U12", "island": "Ha. Ihavandhoo", "label": ""}'::jsonb),
  ('teams', 't07', '{"academy": "Vaalu Academy", "age": "U10", "island": "R. Maduvvaree", "label": ""}'::jsonb),
  ('teams', 't08', '{"academy": "Vaalu Academy", "age": "U12", "island": "R. Maduvvaree", "label": ""}'::jsonb),
  ('teams', 't09', '{"academy": "Capital Sports Academy", "age": "U10", "island": "Ha. Baarah", "label": ""}'::jsonb),
  ('teams', 't10', '{"academy": "Capital Sports Academy", "age": "U10", "island": "Ha. Baarah", "label": "B"}'::jsonb),
  ('teams', 't11', '{"academy": "Maldives Soccer Mates", "age": "U10", "island": "Male", "label": ""}'::jsonb),
  ('teams', 't12', '{"academy": "Maldives Soccer Mates", "age": "U12", "island": "Male", "label": "A"}'::jsonb),
  ('teams', 't13', '{"academy": "Maldives Soccer Mates", "age": "U12", "island": "Male", "label": "B"}'::jsonb),
  ('teams', 't14', '{"academy": "Kelaa Sports Academy", "age": "U10", "island": "Ha. Kelaa", "label": "A"}'::jsonb),
  ('teams', 't15', '{"academy": "Kelaa Sports Academy", "age": "U10", "island": "Ha. Kelaa", "label": ""}'::jsonb),
  ('teams', 't16', '{"academy": "Kelaa Sports Academy", "age": "U12", "island": "Ha. Kelaa", "label": ""}'::jsonb),
  ('teams', 't17', '{"academy": "Kelaa Sports Academy", "age": "U12", "island": "Ha. Kelaa", "label": "A"}'::jsonb),
  ('teams', 't18', '{"academy": "Kelaa Sports Academy", "age": "U12", "island": "Ha. Kelaa", "label": "A"}'::jsonb),
  ('teams', 't19', '{"academy": "Dhidhdhoo Sports Academy", "age": "U10", "island": "Ha. Dhidhdhoo", "label": ""}'::jsonb),
  ('teams', 't20', '{"academy": "Dhidhdhoo Sports Academy", "age": "U12", "island": "Ha. Dhidhdhoo", "label": ""}'::jsonb),
  ('teams', 't21', '{"academy": "Nolhivaram Madrid Sports Academy", "age": "U10", "island": "HDh. Nolhivaran", "label": ""}'::jsonb),
  ('teams', 't22', '{"academy": "Nolhivaram Madrid Sports Academy", "age": "U12", "island": "HDh. Nolhivaran", "label": ""}'::jsonb),
  ('teams', 't23', '{"academy": "Nolhivaram Madrid Sports Academy", "age": "U12", "island": "HDh. Nolhivaran", "label": "B"}'::jsonb),
  ('teams', 't24', '{"academy": "Vazan Sports Academy", "age": "U10", "island": "HDh. Nolhivaranfaru", "label": ""}'::jsonb),
  ('teams', 't25', '{"academy": "Vazan Sports Academy", "age": "U12", "island": "HDh. Nolhivaranfaru", "label": ""}'::jsonb),
  ('teams', 't26', '{"academy": "NFN Football Academy", "age": "U10", "island": "Sh. Milandhoo", "label": ""}'::jsonb),
  ('teams', 't27', '{"academy": "NFN Football Academy", "age": "U12", "island": "Sh. Milandhoo", "label": ""}'::jsonb),
  ('teams', 't28', '{"academy": "FATO Sports Academy", "age": "U12", "island": "HDh. Nellaidhoo", "label": ""}'::jsonb),
  ('teams', 't29', '{"academy": "Hurriyyaa Football Academy", "age": "U12", "island": "K. Huraa", "label": ""}'::jsonb),
  ('teams', 't30', '{"academy": "J Sports Academy", "age": "U10", "island": "Ha. Ihavandhoo", "label": ""}'::jsonb),
  ('teams', 't31', '{"academy": "J Sports Academy", "age": "U12", "island": "Ha. Ihavandhoo", "label": ""}'::jsonb),
  ('teams', 't32', '{"academy": "Hanimaadhoo Fannu Academy", "age": "U10", "island": "HDh. Hanimaadhoo", "label": "A"}'::jsonb),
  ('teams', 't33', '{"academy": "Hanimaadhoo Fannu Academy", "age": "U10", "island": "HDh. Hanimaadhoo", "label": "B"}'::jsonb),
  ('teams', 't34', '{"academy": "Hanimaadhoo Fannu Academy", "age": "U12", "island": "HDh. Hanimaadhoo", "label": "A"}'::jsonb),
  ('teams', 't35', '{"academy": "Hanimaadhoo Fannu Academy", "age": "U12", "island": "HDh. Hanimaadhoo", "label": "B"}'::jsonb),
  ('teams', 't36', '{"academy": "Adventures Football Academy", "age": "U12", "island": "Hulhumale''", "label": ""}'::jsonb),
  ('settings', 'main', '{"focal": "Abdulla Ali · 7572743"}'::jsonb)
on conflict (collection, id) do nothing;
