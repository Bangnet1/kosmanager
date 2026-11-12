-- Require an assigned active package before customers can add or move rooms.
-- Administrators remain exempt. Existing rooms are not deleted or changed.
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

  if v_plan_id is null then
    raise exception using errcode = 'P0001', message = 'ROOM_PLAN_NOT_ASSIGNED';
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

revoke all on function public.enforce_owner_room_limit() from public, anon, authenticated;
