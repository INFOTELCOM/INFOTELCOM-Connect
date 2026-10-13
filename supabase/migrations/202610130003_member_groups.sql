-- Groupes créés par les membres : un groupe est un canal de discussion.
-- À exécuter une seule fois dans Supabase SQL Editor.
create or replace function public.connect_create_channel(
 p_organization_id uuid,
 p_name text,
 p_description text default '',
 p_private boolean default false
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
 v_id uuid;
 v_name text;
begin
 if auth.uid() is null then
  raise exception 'Authentification requise';
 end if;

 if not exists (
  select 1 from public.connect_members
  where organization_id=p_organization_id and user_id=auth.uid()
 ) then
  raise exception 'Tu dois être membre de cet espace pour créer un groupe';
 end if;

 v_name := lower(trim(p_name));
 if v_name !~ '^[a-z0-9][a-z0-9_-]{0,39}$' then
  raise exception 'Nom invalide: lettres minuscules, chiffres, tirets et underscores uniquement';
 end if;

 insert into public.connect_channels(organization_id,name,description,is_private,created_by)
 values(p_organization_id,v_name,left(coalesce(p_description,''),240),coalesce(p_private,false),auth.uid())
 returning id into v_id;

 if not coalesce(p_private,false) then
  insert into public.connect_channel_members(channel_id,user_id)
  select v_id,user_id from public.connect_members
  where organization_id=p_organization_id
  on conflict do nothing;
 else
  insert into public.connect_channel_members(channel_id,user_id)
  values(v_id,auth.uid())
  on conflict do nothing;
 end if;

 return v_id;
end;
$$;

revoke all on function public.connect_create_channel(uuid,text,text,boolean) from public, anon;
grant execute on function public.connect_create_channel(uuid,text,text,boolean) to authenticated;
