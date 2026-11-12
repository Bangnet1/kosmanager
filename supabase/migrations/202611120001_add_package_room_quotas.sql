-- Define the maximum number of rooms that a subscription package may own.
alter table public.subscription_plans
  add column if not exists max_rooms integer not null default 10;

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'subscription_plans_max_rooms_check'
      and conrelid = 'public.subscription_plans'::regclass
  ) then
    alter table public.subscription_plans
      add constraint subscription_plans_max_rooms_check
      check (max_rooms between 1 and 10000);
  end if;
end
$$;

create index if not exists idx_rooms_owner_id_quota
  on public.rooms (owner_id);

create or replace function public.enforce_owner_room_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner_id uuid;
  v_is_admin boolean := false;
  v_plan_id uuid;
  v_subscription_active boolean;
  v_expires_at timestamptz;
  v_room_limit integer;
  v_room_count bigint;
begin
  v_owner_id := new.owner_id;

  if v_owner_id is null then
    raise exception using errcode = 'P0001', message = 'ROOM_OWNER_REQUIRED';
  end if;

  if auth.uid() is not null and auth.uid() <> v_owner_id then
    raise exception using errcode = 'P0001', message = 'ROOM_OWNER_MISMATCH';
  end if;

  select exists (
    select 1 from public.admin_users a where a.user_id = v_owner_id
  ) into v_is_admin;

  if v_is_admin then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.owner_id = new.owner_id then
    return new;
  end if;

  -- Serialize room additions per owner so simultaneous requests cannot exceed the limit.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_owner_id::text, 0)
  );

  select s.plan_id, s.is_active, s.expires_at, p.max_rooms
    into v_plan_id, v_subscription_active, v_expires_at, v_room_limit
  from public.user_subscriptions s
  left join public.subscription_plans p on p.id = s.plan_id
  where s.user_id = v_owner_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'ROOM_SUBSCRIPTION_NOT_FOUND';
  end if;

  if v_subscription_active is not true or v_expires_at <= pg_catalog.now() then
    raise exception using errcode = 'P0001', message = 'ROOM_SUBSCRIPTION_INACTIVE';
  end if;

  -- Legacy accounts without an assigned package keep their existing ability to operate
  -- until an administrator assigns a package.
  if v_plan_id is null then
    return new;
  end if;

  if v_room_limit is null then
    raise exception using errcode = 'P0001', message = 'ROOM_LIMIT_NOT_CONFIGURED';
  end if;

  select pg_catalog.count(*) into v_room_count
  from public.rooms r
  where r.owner_id = v_owner_id;

  if v_room_count >= v_room_limit then
    raise exception using
      errcode = 'P0001',
      message = 'ROOM_LIMIT_REACHED',
      detail = pg_catalog.format(
        'Paket ini mengizinkan maksimal %s kamar. Saat ini sudah digunakan %s kamar.',
        v_room_limit, v_room_count
      );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_owner_room_limit on public.rooms;

create trigger trg_enforce_owner_room_limit
before insert or update on public.rooms
for each row
execute function public.enforce_owner_room_limit();

-- A trigger invokes the function; authenticated users must not call the helper directly.
revoke all on function public.enforce_owner_room_limit() from public, anon, authenticated;
