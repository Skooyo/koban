-- Groups: accounts, groups, members, join requests, shared totals, budget limits.
-- Spec: docs/superpowers/specs/2026-11-12-group-tracker-design.md. The app talks to these tables with
-- supabase-kt and the publishable key; row-level security decides what each signed-in person reads.

create schema if not exists private;

create table public.profiles (
  user_id uuid primary key references auth.users on delete cascade,
  alias text not null check (char_length(btrim(alias)) between 1 and 30),
  invite_id bigint not null references public.invite_codes,
  totals_updated_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 40),
  owner_id uuid references public.profiles (user_id) on delete set null,
  code text not null unique,
  created_at timestamptz not null default now()
);

create table public.group_members (
  group_id uuid not null references public.groups on delete cascade,
  user_id uuid not null references public.profiles on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index on public.group_members (user_id);

create table public.join_requests (
  group_id uuid not null references public.groups on delete cascade,
  user_id uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index on public.join_requests (user_id);

-- One row per person, account, period and category. "Total" rows are not stored; the app sums.
create table public.shared_totals (
  user_id uuid not null references public.profiles on delete cascade,
  currency text not null check (currency in ('MYR', 'IDR')),
  period text not null check (period in ('week', 'month')),
  period_start date not null,
  category text not null check (char_length(category) between 1 and 40),
  amount numeric(14, 2) not null check (amount >= 0),
  primary key (user_id, currency, period, period_start, category)
);

-- A personal budget limit; category 'Total' is the limit for all spending in the period.
create table public.budget_limits (
  user_id uuid not null references public.profiles on delete cascade,
  currency text not null check (currency in ('MYR', 'IDR')),
  period text not null check (period in ('week', 'month')),
  category text not null check (char_length(category) between 1 and 40),
  amount numeric(14, 2) not null check (amount > 0),
  primary key (user_id, currency, period, category)
);

-- "You were removed from <group>", shown once.
create table public.removed_notices (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles on delete cascade,
  group_name text not null,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.join_requests enable row level security;
alter table public.shared_totals enable row level security;
alter table public.budget_limits enable row level security;
alter table public.removed_notices enable row level security;

-- ---- Helpers (security definer: they read group_members without running its policy, so no recursion) ----

create function private.my_group_ids() returns setof uuid
language sql security definer set search_path = '' stable as $$
  select group_id from public.group_members where user_id = (select auth.uid())
$$;

create function private.my_owned_group_ids() returns setof uuid
language sql security definer set search_path = '' stable as $$
  select id from public.groups where owner_id = (select auth.uid())
$$;

/** First day of the Malaysian week (Monday) or month that holds ts. */
create function private.period_start(ts timestamptz, p text) returns date
language sql immutable set search_path = '' as $$
  select date_trunc(case when p = 'week' then 'week' else 'month' end, ts at time zone 'Asia/Kuala_Lumpur')::date
$$;

/** True when the caller may see this person's row for this period: it is the caller's own row, or the two
    share a group and the period starts no earlier than the period in which the later of the two joined. */
create function private.can_see(p_user uuid, p_period text, p_start date) returns boolean
language sql security definer set search_path = '' stable as $$
  select p_user = (select auth.uid()) or exists (
    select 1 from public.group_members a join public.group_members b on a.group_id = b.group_id
    where a.user_id = (select auth.uid()) and b.user_id = p_user
      and (p_start is null or p_start >= private.period_start(greatest(a.joined_at, b.joined_at), p_period)))
$$;

/** Members of the caller's groups, and people who asked to join a group the caller owns. */
create function private.visible_people() returns setof uuid
language sql security definer set search_path = '' stable as $$
  select b.user_id from public.group_members a join public.group_members b on a.group_id = b.group_id
  where a.user_id = (select auth.uid())
  union
  select r.user_id from public.join_requests r join public.groups g on g.id = r.group_id
  where g.owner_id = (select auth.uid())
$$;

-- ---- Policies: reads. Writes go through the functions below, except the person's own totals and limits. ----

create policy "own and visible profiles" on public.profiles for select to authenticated
  using (user_id = (select auth.uid()) or user_id in (select private.visible_people()));
create policy "own alias" on public.profiles for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
revoke update on public.profiles from authenticated;
grant update (alias, totals_updated_at) on public.profiles to authenticated;

create policy "my groups" on public.groups for select to authenticated
  using (id in (select private.my_group_ids()));

create policy "members of my groups" on public.group_members for select to authenticated
  using (group_id in (select private.my_group_ids()));

create policy "my requests and requests to my groups" on public.join_requests for select to authenticated
  using ((user_id = (select auth.uid()) or group_id in (select private.my_owned_group_ids()))
         and created_at > now() - interval '7 days');

create policy "read shared totals" on public.shared_totals for select to authenticated
  using (private.can_see(user_id, period, period_start));
create policy "write own totals while in a group" on public.shared_totals for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and exists (select 1 from private.my_group_ids()));

create policy "read budget limits" on public.budget_limits for select to authenticated
  using (private.can_see(user_id, period, null));
create policy "write own limits while in a group" on public.budget_limits for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()) and exists (select 1 from private.my_group_ids()));

create policy "own notices" on public.removed_notices for select to authenticated
  using (user_id = (select auth.uid()));
create policy "dismiss own notices" on public.removed_notices for delete to authenticated
  using (user_id = (select auth.uid()));

-- ---- After a member leaves: pass the owner role on, delete an empty group, clean up a person in no group ----

create function private.after_member_left() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.group_members where group_id = old.group_id) then
    delete from public.groups where id = old.group_id;
  else
    update public.groups g set owner_id = (
      select user_id from public.group_members where group_id = old.group_id order by joined_at, user_id limit 1)
    where g.id = old.group_id and (g.owner_id is null or g.owner_id = old.user_id);
  end if;
  if not exists (select 1 from public.group_members where user_id = old.user_id) then
    delete from public.shared_totals where user_id = old.user_id;
    delete from public.budget_limits where user_id = old.user_id;
  end if;
  return null;
end $$;
create trigger member_left after delete on public.group_members
  for each row execute function private.after_member_left();

-- ---- Group actions. Each returns a short status word the app maps to a message. ----

create function private.new_code() returns text
language plpgsql set search_path = '' as $$
declare
  v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';  -- no 0/O or 1/I, as invite codes
  v_code text;
begin
  loop
    v_code := 'GRP-';
    for i in 1..4 loop
      v_code := v_code || substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.groups where code = v_code);
  end loop;
  return v_code;
end $$;

/** First sign-in: links the account to the invite code of the phone's device token. */
create function public.link_account(p_device_token text, p_alias text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_invite bigint;
begin
  if (select auth.uid()) is null then return 'signed_out'; end if;
  if exists (select 1 from public.profiles where user_id = (select auth.uid())) then return 'ok'; end if;
  select d.invite_id into v_invite
  from public.devices d join public.invite_codes i on i.id = d.invite_id
  where d.token_hash = encode(extensions.digest(coalesce(p_device_token, ''), 'sha256'), 'hex')
    and i.cancelled_at is null;
  if v_invite is null then return 'no_invite'; end if;
  insert into public.profiles (user_id, alias, invite_id)
  values ((select auth.uid()), left(coalesce(nullif(btrim(p_alias), ''), 'Friend'), 30), v_invite);
  return 'ok';
end $$;

/** True when the caller has an account whose invite code is still active. */
create function private.active_account() returns boolean
language sql security definer set search_path = '' stable as $$
  select exists (select 1 from public.profiles p join public.invite_codes i on i.id = p.invite_id
                 where p.user_id = (select auth.uid()) and i.cancelled_at is null)
$$;

create function public.make_group(p_name text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
  v_code text;
begin
  if not private.active_account() then return jsonb_build_object('status', 'no_account'); end if;
  if char_length(btrim(coalesce(p_name, ''))) not between 1 and 40 then return jsonb_build_object('status', 'bad_name'); end if;
  if (select count(*) from public.group_members where user_id = (select auth.uid())) >= 5 then
    return jsonb_build_object('status', 'too_many_groups');
  end if;
  v_code := private.new_code();
  insert into public.groups (name, owner_id, code) values (btrim(p_name), (select auth.uid()), v_code) returning id into v_id;
  insert into public.group_members (group_id, user_id) values (v_id, (select auth.uid()));
  return jsonb_build_object('status', 'ok', 'id', v_id, 'code', v_code);
end $$;

create function public.ask_to_join(p_code text) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_group uuid;
begin
  if not private.active_account() then return 'no_account'; end if;
  select id into v_group from public.groups where code = upper(btrim(coalesce(p_code, '')));
  if v_group is null then return 'unknown'; end if;
  if exists (select 1 from public.group_members where group_id = v_group and user_id = (select auth.uid())) then
    return 'already';
  end if;
  if (select count(*) from public.group_members where user_id = (select auth.uid())) >= 5 then return 'too_many_groups'; end if;
  if (select count(*) from public.group_members where group_id = v_group) >= 10 then return 'full'; end if;
  if (select count(*) from public.join_requests where user_id = (select auth.uid()) and created_at > now() - interval '7 days') >= 5 then
    return 'too_many_requests';
  end if;
  insert into public.join_requests (group_id, user_id) values (v_group, (select auth.uid()))
  on conflict (group_id, user_id) do update set created_at = now();
  delete from public.removed_notices where user_id = (select auth.uid());
  return 'ok';
end $$;

create function public.answer_request(p_group uuid, p_user uuid, p_approve boolean) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_fresh boolean;
begin
  if not exists (select 1 from public.groups where id = p_group and owner_id = (select auth.uid())) then return 'not_owner'; end if;
  delete from public.join_requests where group_id = p_group and user_id = p_user
  returning created_at > now() - interval '7 days' into v_fresh;
  if v_fresh is null or not v_fresh then return 'expired'; end if;
  if not p_approve then return 'declined'; end if;
  if (select count(*) from public.group_members where group_id = p_group) >= 10 then return 'full'; end if;
  if (select count(*) from public.group_members where user_id = p_user) >= 5 then return 'too_many_groups'; end if;
  insert into public.group_members (group_id, user_id) values (p_group, p_user) on conflict do nothing;
  return 'ok';
end $$;

create function public.leave_group(p_group uuid) returns text
language plpgsql security definer set search_path = '' as $$
begin
  delete from public.group_members where group_id = p_group and user_id = (select auth.uid());
  return case when found then 'ok' else 'not_member' end;
end $$;

create function public.remove_member(p_group uuid, p_user uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_name text;
begin
  select name into v_name from public.groups where id = p_group and owner_id = (select auth.uid());
  if v_name is null then return 'not_owner'; end if;
  if p_user = (select auth.uid()) then return 'use_leave'; end if;
  delete from public.group_members where group_id = p_group and user_id = p_user;
  if not found then return 'not_member'; end if;
  insert into public.removed_notices (user_id, group_name) values (p_user, v_name);
  return 'ok';
end $$;

create function public.hand_over(p_group uuid, p_user uuid) returns text
language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from public.groups where id = p_group and owner_id = (select auth.uid())) then return 'not_owner'; end if;
  if not exists (select 1 from public.group_members where group_id = p_group and user_id = p_user) then return 'not_member'; end if;
  update public.groups set owner_id = p_user where id = p_group;
  return 'ok';
end $$;

create function public.rename_group(p_group uuid, p_name text) returns text
language plpgsql security definer set search_path = '' as $$
begin
  if char_length(btrim(coalesce(p_name, ''))) not between 1 and 40 then return 'bad_name'; end if;
  update public.groups set name = btrim(p_name) where id = p_group and owner_id = (select auth.uid());
  return case when found then 'ok' else 'not_owner' end;
end $$;

create function public.new_group_code(p_group uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare
  v_code text := private.new_code();
begin
  update public.groups set code = v_code where id = p_group and owner_id = (select auth.uid());
  return case when found then v_code else 'not_owner' end;
end $$;

-- Only signed-in people call the group actions; the helpers are not callable at all.
revoke execute on all functions in schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.my_group_ids(), private.my_owned_group_ids(), private.can_see(uuid, text, date),
  private.visible_people(), private.period_start(timestamptz, text) to authenticated;
revoke execute on function public.link_account(text, text), public.make_group(text), public.ask_to_join(text),
  public.answer_request(uuid, uuid, boolean), public.leave_group(uuid), public.remove_member(uuid, uuid),
  public.hand_over(uuid, uuid), public.rename_group(uuid, text), public.new_group_code(uuid) from public, anon;
grant execute on function public.link_account(text, text), public.make_group(text), public.ask_to_join(text),
  public.answer_request(uuid, uuid, boolean), public.leave_group(uuid), public.remove_member(uuid, uuid),
  public.hand_over(uuid, uuid), public.rename_group(uuid, text), public.new_group_code(uuid) to authenticated;
