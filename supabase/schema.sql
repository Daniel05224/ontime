-- ─────────────────────────────────────────────────────────────────────────────
-- OnTime – schema completo
-- Cole e execute no SQL Editor do Supabase
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. PROFILES ─────────────────────────────────────────────────────────────────
create table if not exists public.profiles (
  id         uuid        references auth.users(id) on delete cascade primary key,
  name       text        not null default '',
  avatar_url text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_select" on public.profiles for select using (true);
create policy "profiles_insert" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

-- Cria perfil automaticamente ao criar conta
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 2. FRIENDSHIPS ──────────────────────────────────────────────────────────────
create table if not exists public.friendships (
  id           uuid default gen_random_uuid() primary key,
  requester_id uuid references public.profiles(id) on delete cascade not null,
  addressee_id uuid references public.profiles(id) on delete cascade not null,
  status       text not null default 'pending' check (status in ('pending','accepted')),
  created_at   timestamptz not null default now(),
  unique(requester_id, addressee_id)
);

alter table public.friendships enable row level security;

create policy "friendships_select" on public.friendships for select
  using (auth.uid() = requester_id or auth.uid() = addressee_id);
create policy "friendships_insert" on public.friendships for insert
  with check (auth.uid() = requester_id);
create policy "friendships_update" on public.friendships for update
  using (auth.uid() = requester_id or auth.uid() = addressee_id);
create policy "friendships_delete" on public.friendships for delete
  using (auth.uid() = requester_id or auth.uid() = addressee_id);

-- 3. STATUSES (status ao vivo – um por usuário) ───────────────────────────────
create table if not exists public.statuses (
  id          uuid    default gen_random_uuid() primary key,
  user_id     uuid    references public.profiles(id) on delete cascade not null unique,
  vibe_emoji  text    not null,
  vibe_label  text    not null,
  vibe_color  bigint  not null,
  period      text    not null check (period in ('morning','afternoon','evening','night')),
  posted_at   timestamptz not null default now()
);

alter table public.statuses enable row level security;

create policy "statuses_select" on public.statuses for select using (true);
create policy "statuses_insert" on public.statuses for insert with check (auth.uid() = user_id);
create policy "statuses_update" on public.statuses for update using (auth.uid() = user_id);
create policy "statuses_delete" on public.statuses for delete using (auth.uid() = user_id);

-- 4. DAY PLANS (plano do dia – um por usuário por data) ───────────────────────
create table if not exists public.day_plans (
  id        uuid  default gen_random_uuid() primary key,
  user_id   uuid  references public.profiles(id) on delete cascade not null,
  plan_date date  not null default current_date,
  periods   jsonb not null default '{}',
  created_at timestamptz not null default now(),
  unique(user_id, plan_date)
);

alter table public.day_plans enable row level security;

create policy "day_plans_select" on public.day_plans for select using (true);
create policy "day_plans_insert" on public.day_plans for insert with check (auth.uid() = user_id);
create policy "day_plans_update" on public.day_plans for update using (auth.uid() = user_id);
create policy "day_plans_delete" on public.day_plans for delete using (auth.uid() = user_id);

-- 5. EXCLUIR PRÓPRIA CONTA ────────────────────────────────────────────────────
create or replace function public.delete_own_account()
returns void language plpgsql security definer set search_path = ''
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

-- 6. REALTIME ─────────────────────────────────────────────────────────────────
alter publication supabase_realtime add table public.statuses;
alter publication supabase_realtime add table public.day_plans;
