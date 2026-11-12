-- Online access for Koban: invite codes, device tokens and daily Claude read limits.
-- Only the Edge Functions (service role) and the owner (SQL editor) reach these tables.
-- Limits: 10 reads a day per device, 15 per invite code, 150 for all; the day is Malaysia time (UTC+8).

create table public.invite_codes (
  id bigint generated always as identity primary key,
  friend_name text not null unique,
  code text not null unique,
  max_devices int not null default 2,
  cancelled_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.devices (
  id bigint generated always as identity primary key,
  invite_id bigint not null references public.invite_codes(id) on delete cascade,
  token_hash text not null unique,  -- sha256 hex of the device token; the token itself is never stored
  created_at timestamptz not null default now()
);
create index on public.devices (invite_id);

create table public.reads (
  id bigint generated always as identity primary key,
  device_id bigint not null references public.devices(id) on delete cascade,
  day date not null,
  status text not null default 'pending',  -- pending | ok | failed
  created_at timestamptz not null default now()
);
create index on public.reads (day, device_id);

create table public.register_attempts (
  ip text not null,
  at timestamptz not null default now()
);
create index on public.register_attempts (ip, at);

alter table public.invite_codes enable row level security;
alter table public.devices enable row level security;
alter table public.reads enable row level security;
alter table public.register_attempts enable row level security;
-- No policies: anon and authenticated users can read or write nothing.

create function public.koban_today() returns date
language sql stable as $$ select (now() at time zone 'Asia/Kuala_Lumpur')::date $$;

-- Register a device. Returns 'ok', 'malformed', 'refused' (unknown, cancelled or full code) or 'too_many'.
create function public.register_device(p_code text, p_token_hash text, p_ip text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_invite public.invite_codes%rowtype;
  v_code text := upper(trim(p_code));
begin
  insert into public.register_attempts (ip) values (coalesce(p_ip, '?'));
  if (select count(*) from public.register_attempts
      where ip = coalesce(p_ip, '?') and at > now() - interval '1 hour') > 10 then
    return 'too_many';
  end if;
  if v_code !~ '^[A-Z0-9]{4}-[A-Z0-9]{4}$' then return 'malformed'; end if;
  select * into v_invite from public.invite_codes where code = v_code and cancelled_at is null for update;
  if not found then return 'refused'; end if;
  if (select count(*) from public.devices where invite_id = v_invite.id) >= v_invite.max_devices then
    return 'refused';
  end if;
  insert into public.devices (invite_id, token_hash) values (v_invite.id, p_token_hash);
  return 'ok';
end $$;

-- Reserve one Claude read. Returns {ok, read_id, reads_left} or {ok: false, reason: 'unknown' | 'device' | 'code' | 'all'}.
create function public.reserve_read(p_token_hash text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_device bigint;
  v_invite bigint;
  v_day date := public.koban_today();
  v_dev_used int;
  v_read bigint;
begin
  perform pg_advisory_xact_lock(4242);  -- one reservation at a time keeps the counts exact
  select d.id, d.invite_id into v_device, v_invite
  from public.devices d join public.invite_codes i on i.id = d.invite_id
  where d.token_hash = p_token_hash and i.cancelled_at is null;
  if v_device is null then return jsonb_build_object('ok', false, 'reason', 'unknown'); end if;
  select count(*) into v_dev_used from public.reads where day = v_day and device_id = v_device;
  if v_dev_used >= 10 then return jsonb_build_object('ok', false, 'reason', 'device'); end if;
  if (select count(*) from public.reads r join public.devices d on d.id = r.device_id
      where r.day = v_day and d.invite_id = v_invite) >= 15 then
    return jsonb_build_object('ok', false, 'reason', 'code');
  end if;
  if (select count(*) from public.reads where day = v_day) >= 150 then
    return jsonb_build_object('ok', false, 'reason', 'all');
  end if;
  insert into public.reads (device_id, day) values (v_device, v_day) returning id into v_read;
  return jsonb_build_object('ok', true, 'read_id', v_read, 'reads_left', 10 - v_dev_used - 1);
end $$;

-- Finish a reserved read. Claude ran (ok / failed): the read counts. Claude did not run (released): it is removed.
create function public.finish_read(p_read_id bigint, p_status text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if p_status = 'released' then
    delete from public.reads where id = p_read_id;
  else
    update public.reads set status = p_status where id = p_read_id;
  end if;
end $$;

-- Owner tools for the SQL editor: select public.new_invite('Aisyah'); select public.cancel_invite('Aisyah');
create function public.new_invite(p_friend_name text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';  -- no 0/O or 1/I
  v_code text;
begin
  loop
    v_code := '';
    for i in 1..8 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
      if i = 4 then v_code := v_code || '-'; end if;
    end loop;
    exit when not exists (select 1 from public.invite_codes where code = v_code);
  end loop;
  insert into public.invite_codes (friend_name, code) values (trim(p_friend_name), v_code);
  return v_code;
end $$;

create function public.cancel_invite(p_friend_name text) returns text
language plpgsql security definer set search_path = '' as $$
begin
  update public.invite_codes set cancelled_at = now() where friend_name = trim(p_friend_name) and cancelled_at is null;
  if not found then return 'No active invite for ' || p_friend_name; end if;
  return 'Cancelled ' || p_friend_name;
end $$;

-- Keep-alive: a daily call from the owner's server is database activity, so the free project does not pause.
create function public.ping() returns int language sql stable as $$ select 1 $$;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.ping() to anon;
