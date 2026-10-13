-- Social profile, status, discoverable workspaces and moderated join requests.
-- Does not drop existing data or tables.
alter table public.connect_profiles add column if not exists avatar_url text;
alter table public.connect_profiles add column if not exists bio text;
alter table public.connect_profiles add column if not exists presence_status text not null default 'online'
 check (presence_status in ('online','away','busy','offline'));
alter table public.connect_profiles add column if not exists updated_at timestamptz not null default now();

alter table public.connect_organizations add column if not exists discoverable boolean not null default true;
alter table public.connect_organizations add column if not exists public_description text;

create table if not exists public.connect_status_posts (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 organization_id uuid not null references public.connect_organizations(id) on delete cascade,
 text_content text,
 media_path text,
 media_type text,
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default (now()+interval '24 hours'),
 check (text_content is not null or media_path is not null)
);
create index if not exists connect_status_posts_org_expiry_idx on public.connect_status_posts(organization_id,expires_at desc);
alter table public.connect_status_posts enable row level security;
drop policy if exists connect_status_posts_read_members on public.connect_status_posts;
create policy connect_status_posts_read_members on public.connect_status_posts for select to authenticated
using (expires_at>now() and exists(select 1 from public.connect_members m where m.organization_id=connect_status_posts.organization_id and m.user_id=auth.uid()));
drop policy if exists connect_status_posts_insert_self on public.connect_status_posts;
create policy connect_status_posts_insert_self on public.connect_status_posts for insert to authenticated
with check (user_id=auth.uid() and exists(select 1 from public.connect_members m where m.organization_id=connect_status_posts.organization_id and m.user_id=auth.uid()));
drop policy if exists connect_status_posts_delete_self on public.connect_status_posts;
create policy connect_status_posts_delete_self on public.connect_status_posts for delete to authenticated using(user_id=auth.uid());

create table if not exists public.connect_workspace_join_requests (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.connect_organizations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 message text,
 status text not null default 'pending' check(status in ('pending','approved','rejected','cancelled')),
 reviewed_by uuid references auth.users(id),
 reviewed_at timestamptz,
 created_at timestamptz not null default now(),
 unique(organization_id,user_id)
);
create index if not exists connect_join_requests_org_status_idx on public.connect_workspace_join_requests(organization_id,status,created_at);
alter table public.connect_workspace_join_requests enable row level security;
drop policy if exists connect_join_requests_discover on public.connect_workspace_join_requests;
create policy connect_join_requests_discover on public.connect_workspace_join_requests for select to authenticated
using (user_id=auth.uid() or exists(select 1 from public.connect_members m where m.organization_id=organization_id and m.user_id=auth.uid() and m.role in ('owner','admin','manager')));
drop policy if exists connect_join_requests_create_self on public.connect_workspace_join_requests;
create policy connect_join_requests_create_self on public.connect_workspace_join_requests for insert to authenticated
with check(user_id=auth.uid() and status='pending' and exists(select 1 from public.connect_organizations o where o.id=organization_id and o.discoverable=true) and not exists(select 1 from public.connect_members m where m.organization_id=organization_id and m.user_id=auth.uid()));
drop policy if exists connect_join_requests_review on public.connect_workspace_join_requests;
create policy connect_join_requests_review on public.connect_workspace_join_requests for update to authenticated
using(exists(select 1 from public.connect_members m where m.organization_id=organization_id and m.user_id=auth.uid() and m.role in ('owner','admin','manager')))
with check(status in ('approved','rejected','pending') and exists(select 1 from public.connect_members m where m.organization_id=organization_id and m.user_id=auth.uid() and m.role in ('owner','admin','manager')));

-- Directory shows only explicitly discoverable workspaces, never private member/file data.
alter table public.connect_organizations enable row level security;
drop policy if exists connect_organizations_discoverable_read on public.connect_organizations;
create policy connect_organizations_discoverable_read on public.connect_organizations for select to authenticated
using(discoverable=true or exists(select 1 from public.connect_members m where m.organization_id=id and m.user_id=auth.uid()));

-- Approvals create membership only after an authorized manager approves the request.
create or replace function public.connect_review_join_request(p_request_id uuid,p_decision text)
returns void language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_user uuid; v_role text;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_decision not in ('approved','rejected') then raise exception 'Invalid decision'; end if;
 select organization_id,user_id into v_org,v_user from public.connect_workspace_join_requests where id=p_request_id and status='pending' for update;
 if v_org is null then raise exception 'Pending request not found'; end if;
 select role into v_role from public.connect_members where organization_id=v_org and user_id=auth.uid();
 if v_role not in ('owner','admin','manager') then raise exception 'Not authorized to review requests'; end if;
 update public.connect_workspace_join_requests set status=p_decision,reviewed_by=auth.uid(),reviewed_at=now() where id=p_request_id;
 if p_decision='approved' then
   insert into public.connect_members(organization_id,user_id,role) values(v_org,v_user,'member') on conflict(organization_id,user_id) do nothing;
 end if;
end $$;
revoke all on function public.connect_review_join_request(uuid,text) from public,anon;
grant execute on function public.connect_review_join_request(uuid,text) to authenticated;

-- INFOTELCOM platform operator may appoint an administrator; normal admins cannot.
create or replace function public.connect_set_member_role(p_organization_id uuid,p_user_id uuid,p_new_role text)
returns void language plpgsql security definer set search_path=public as $$
declare v_actor_role text; v_target_role text; v_platform_operator boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 v_platform_operator := lower(coalesce(auth.jwt()->>'email',''))='contact.infotelcom@gmail.com';
 select role into v_actor_role from public.connect_members where organization_id=p_organization_id and user_id=auth.uid();
 if not v_platform_operator and v_actor_role not in ('owner','admin') then raise exception 'Only an owner, administrator or authorized INFOTELCOM operator can change roles'; end if;
 if p_new_role not in ('admin','manager','member','guest') then raise exception 'Invalid role'; end if;
 select role into v_target_role from public.connect_members where organization_id=p_organization_id and user_id=p_user_id;
 if v_target_role is null then raise exception 'Member not found'; end if;
 if v_target_role='owner' then raise exception 'The owner role cannot be changed here'; end if;
 if not v_platform_operator and v_actor_role='admin' and p_new_role='admin' then raise exception 'Only the owner or INFOTELCOM operator can appoint an administrator'; end if;
 update public.connect_members set role=p_new_role where organization_id=p_organization_id and user_id=p_user_id;
 insert into public.connect_audit_logs(organization_id,actor_id,action,details)
 values(p_organization_id,auth.uid(),'member.role_changed',jsonb_build_object('target_user_id',p_user_id,'new_role',p_new_role));
end $$;
revoke all on function public.connect_set_member_role(uuid,uuid,text) from public,anon;
grant execute on function public.connect_set_member_role(uuid,uuid,text) to authenticated;
