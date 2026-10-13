-- Migration additive: invitations, profils, fonctions de gestion et politiques de base.
create extension if not exists pgcrypto;

create table if not exists public.connect_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '',
 avatar_url text,
 updated_at timestamptz not null default now()
);

create table if not exists public.connect_invitations (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.connect_organizations(id) on delete cascade,
 email text not null,
 role text not null default 'member' check (role in ('member','admin')),
 token_hash text not null unique,
 invited_by uuid not null references auth.users(id),
 expires_at timestamptz not null default (now() + interval '7 days'),
 accepted_at timestamptz,
 created_at timestamptz not null default now()
);
create index if not exists connect_invitations_org_idx on public.connect_invitations(organization_id,created_at desc);

alter table public.connect_profiles enable row level security;
alter table public.connect_invitations enable row level security;

drop policy if exists connect_profiles_read_workspace on public.connect_profiles;
create policy connect_profiles_read_workspace on public.connect_profiles for select to authenticated using (
 user_id = auth.uid() or exists (
  select 1 from public.connect_members a join public.connect_members b on a.organization_id=b.organization_id
  where a.user_id=auth.uid() and b.user_id=connect_profiles.user_id
 )
);
drop policy if exists connect_profiles_insert_self on public.connect_profiles;
create policy connect_profiles_insert_self on public.connect_profiles for insert to authenticated with check (user_id=auth.uid());
drop policy if exists connect_profiles_update_self on public.connect_profiles;
create policy connect_profiles_update_self on public.connect_profiles for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
-- Invitations are intentionally never directly selectable by regular clients; RPCs mediate access.

create or replace function public.connect_create_invitation(p_organization_id uuid,p_email text,p_role text default 'member')
returns table(invitation_token text, invitation_expires_at timestamptz)
language plpgsql security definer set search_path=public,extensions as $$
declare v_token text; v_email text;
begin
 if auth.uid() is null then raise exception 'Authentification requise'; end if;
 if not public.connect_is_org_admin(p_organization_id) then raise exception 'Droits administrateur requis'; end if;
 v_email := lower(trim(p_email));
 if v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Adresse e-mail invalide'; end if;
 if p_role not in ('member','admin') then raise exception 'Rôle invalide'; end if;
 v_token := encode(gen_random_bytes(32),'hex');
 insert into public.connect_invitations(organization_id,email,role,token_hash,invited_by)
 values(p_organization_id,v_email,p_role,encode(digest(v_token,'sha256'),'hex'),auth.uid());
 return query select v_token, now()+interval '7 days';
end $$;

create or replace function public.connect_accept_invitation(p_token text)
returns uuid language plpgsql security definer set search_path=public,extensions as $$
declare v_inv public.connect_invitations%rowtype; v_email text;
begin
 if auth.uid() is null then raise exception 'Connectez-vous avant d’accepter une invitation'; end if;
 select lower(email) into v_email from auth.users where id=auth.uid();
 select * into v_inv from public.connect_invitations where token_hash=encode(digest(p_token,'sha256'),'hex') for update;
 if not found then raise exception 'Invitation invalide'; end if;
 if v_inv.accepted_at is not null then raise exception 'Invitation déjà utilisée'; end if;
 if v_inv.expires_at < now() then raise exception 'Invitation expirée'; end if;
 if v_email is distinct from lower(v_inv.email) then raise exception 'Connectez-vous avec l’adresse invitée'; end if;
 insert into public.connect_members(organization_id,user_id,role) values(v_inv.organization_id,auth.uid(),v_inv.role)
 on conflict (organization_id,user_id) do nothing;
 update public.connect_invitations set accepted_at=now() where id=v_inv.id;
 return v_inv.organization_id;
end $$;

create or replace function public.connect_create_channel(p_organization_id uuid,p_name text,p_description text default '',p_private boolean default false)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_id uuid; v_name text;
begin
 if auth.uid() is null then raise exception 'Authentification requise'; end if;
 if not public.connect_is_org_admin(p_organization_id) then raise exception 'Droits administrateur requis'; end if;
 v_name := lower(trim(p_name));
 if v_name !~ '^[a-z0-9][a-z0-9_-]{0,39}$' then raise exception 'Nom invalide: lettres minuscules, chiffres, tirets et underscores uniquement'; end if;
 insert into public.connect_channels(organization_id,name,description,is_private,created_by)
 values(p_organization_id,v_name,left(coalesce(p_description,''),240),coalesce(p_private,false),auth.uid()) returning id into v_id;
 if not coalesce(p_private,false) then
  insert into public.connect_channel_members(channel_id,user_id) select v_id,user_id from public.connect_members where organization_id=p_organization_id on conflict do nothing;
 else
  insert into public.connect_channel_members(channel_id,user_id) values(v_id,auth.uid()) on conflict do nothing;
 end if;
 return v_id;
end $$;

create or replace function public.connect_delete_channel(p_channel_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_org uuid;
begin
 select organization_id into v_org from public.connect_channels where id=p_channel_id;
 if v_org is null then raise exception 'Canal introuvable'; end if;
 if not public.connect_is_org_admin(v_org) then raise exception 'Droits administrateur requis'; end if;
 if exists(select 1 from public.connect_channels where id=p_channel_id and name='general') then raise exception 'Le canal general ne peut pas être supprimé'; end if;
 delete from public.connect_channels where id=p_channel_id;
end $$;

-- Grant only the intended callable functions to signed-in users.
grant execute on function public.connect_create_invitation(uuid,text,text) to authenticated;
grant execute on function public.connect_accept_invitation(text) to authenticated;
grant execute on function public.connect_create_channel(uuid,text,text,boolean) to authenticated;
grant execute on function public.connect_delete_channel(uuid) to authenticated;
grant select,insert,update on public.connect_profiles to authenticated;
