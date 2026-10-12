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

-- Add yourself as admin (change the email, then run):
-- insert into public.admins (email) values ('you@example.com');
