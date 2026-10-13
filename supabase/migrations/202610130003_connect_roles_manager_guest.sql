-- Extend invitation roles without deleting existing workspace data.
alter table public.connect_invitations drop constraint if exists connect_invitations_role_check;
alter table public.connect_invitations add constraint connect_invitations_role_check check (role in ('member','admin','manager','guest'));

create or replace function public.connect_create_invitation(p_organization_id uuid,p_email text,p_role text default 'member')
returns table(invitation_token text, invitation_expires_at timestamptz)
language plpgsql security definer set search_path=public,extensions as $$
declare v_token text; v_email text;
begin
 if auth.uid() is null then raise exception 'Authentification requise'; end if;
 if not public.connect_is_org_admin(p_organization_id) then raise exception 'Droits administrateur requis'; end if;
 v_email := lower(trim(p_email));
 if v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Adresse e-mail invalide'; end if;
 if p_role not in ('member','admin','manager','guest') then raise exception 'Rôle invalide'; end if;
 v_token := encode(gen_random_bytes(32),'hex');
 insert into public.connect_invitations(organization_id,email,role,token_hash,invited_by)
 values(p_organization_id,v_email,p_role,encode(digest(v_token,'sha256'),'hex'),auth.uid());
 return query select v_token, now()+interval '7 days';
end $$;
revoke all on function public.connect_create_invitation(uuid,text,text) from public, anon;
grant execute on function public.connect_create_invitation(uuid,text,text) to authenticated;
