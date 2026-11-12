-- An unlimited invite code (the owner's) skips the daily limits and does not count toward the 150 for all friends.
-- Set it in the SQL editor: update public.invite_codes set unlimited = true where friend_name = 'Owner';
alter table public.invite_codes add column unlimited boolean not null default false;

create or replace function public.reserve_read(p_token_hash text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_device bigint;
  v_invite bigint;
  v_unlimited boolean;
  v_day date := public.koban_today();
  v_dev_used int;
  v_read bigint;
begin
  perform pg_advisory_xact_lock(4242);  -- one reservation at a time keeps the counts exact
  select d.id, d.invite_id, i.unlimited into v_device, v_invite, v_unlimited
  from public.devices d join public.invite_codes i on i.id = d.invite_id
  where d.token_hash = p_token_hash and i.cancelled_at is null;
  if v_device is null then return jsonb_build_object('ok', false, 'reason', 'unknown'); end if;
  if v_unlimited then
    insert into public.reads (device_id, day) values (v_device, v_day) returning id into v_read;
    return jsonb_build_object('ok', true, 'read_id', v_read, 'reads_left', null);
  end if;
  select count(*) into v_dev_used from public.reads where day = v_day and device_id = v_device;
  if v_dev_used >= 10 then return jsonb_build_object('ok', false, 'reason', 'device'); end if;
  if (select count(*) from public.reads r join public.devices d on d.id = r.device_id
      where r.day = v_day and d.invite_id = v_invite) >= 15 then
    return jsonb_build_object('ok', false, 'reason', 'code');
  end if;
  if (select count(*) from public.reads r join public.devices d on d.id = r.device_id
      join public.invite_codes i on i.id = d.invite_id
      where r.day = v_day and not i.unlimited) >= 150 then
    return jsonb_build_object('ok', false, 'reason', 'all');
  end if;
  insert into public.reads (device_id, day) values (v_device, v_day) returning id into v_read;
  return jsonb_build_object('ok', true, 'read_id', v_read, 'reads_left', 10 - v_dev_used - 1);
end $$;

revoke execute on function public.reserve_read(text) from public, anon, authenticated;

update public.invite_codes set unlimited = true where friend_name = 'Owner';
