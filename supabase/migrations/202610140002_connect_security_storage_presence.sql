-- Security and completion pass for INFOTELCOM Connect enterprise collaboration.
-- Apply in Supabase SQL Editor or through the project's migration workflow.
create extension if not exists pgcrypto;

-- Harden DM membership: only org members may be invited, and only the conversation
-- creator or an org manager can add another participant.
create or replace function public.connect_create_dm(p_organization_id uuid, p_title text, p_is_group boolean, p_participant_ids uuid[])
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
 v_id uuid;
 v_uid uuid := auth.uid();
 v_participant uuid;
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 if not public.connect_roadmap_is_org_member(p_organization_id) then raise exception 'Not a workspace member'; end if;
 if coalesce(array_length(p_participant_ids,1),0) < 1 then raise exception 'At least one participant is required'; end if;
 if coalesce(array_length(p_participant_ids,1),0) > 50 then raise exception 'Too many participants'; end if;
 insert into public.connect_dm_conversations(organization_id,title,is_group,created_by)
 values(p_organization_id,nullif(trim(p_title),''),coalesce(p_is_group,false),v_uid)
 returning id into v_id;
 insert into public.connect_dm_participants(conversation_id,user_id) values(v_id,v_uid)
 on conflict do nothing;
 foreach v_participant in array p_participant_ids loop
   if not public.connect_roadmap_is_org_member(p_organization_id) then raise exception 'Not a workspace member'; end if;
   if not exists(select 1 from public.connect_members m where m.organization_id=p_organization_id and m.user_id=v_participant) then
     raise exception 'Every participant must belong to this workspace';
   end if;
   insert into public.connect_dm_participants(conversation_id,user_id) values(v_id,v_participant)
   on conflict do nothing;
 end loop;
 if (select count(*) from public.connect_dm_participants p where p.conversation_id=v_id) < 2 then
   raise exception 'A conversation needs at least two participants';
 end if;
 return v_id;
end;
$$;
revoke all on function public.connect_create_dm(uuid,text,boolean,uuid[]) from public, anon;
grant execute on function public.connect_create_dm(uuid,text,boolean,uuid[]) to authenticated;

-- Ensure conversation creators can add the initial participants only while creating
-- via the checked RPC above; direct participant insertion is limited to self or manager.
drop policy if exists connect_dm_participants_insert on public.connect_dm_participants;
create policy connect_dm_participants_insert on public.connect_dm_participants
for insert to authenticated
with check (
 user_id=auth.uid()
 or exists(
   select 1 from public.connect_dm_conversations c
   where c.id=conversation_id
   and public.connect_roadmap_is_org_manager(c.organization_id)
   and exists(select 1 from public.connect_members m where m.organization_id=c.organization_id and m.user_id=user_id)
 )
);

-- No user can mutate another member's read receipt or update another sender's message.
drop policy if exists connect_dm_participants_update_self on public.connect_dm_participants;
create policy connect_dm_participants_update_self on public.connect_dm_participants
for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
drop policy if exists connect_dm_messages_sender_update on public.connect_dm_messages;
create policy connect_dm_messages_sender_update on public.connect_dm_messages
for update to authenticated
using (sender_id=auth.uid() and public.connect_roadmap_is_dm_participant(conversation_id))
with check (sender_id=auth.uid() and public.connect_roadmap_is_dm_participant(conversation_id));

-- Make the audit log append-only to authenticated clients.
drop policy if exists connect_audit_member_insert on public.connect_audit_logs;
create policy connect_audit_member_insert on public.connect_audit_logs
for insert to authenticated
with check (public.connect_roadmap_is_org_member(organization_id) and actor_id=auth.uid());
drop policy if exists connect_audit_member_update on public.connect_audit_logs;
create policy connect_audit_member_update on public.connect_audit_logs for update to authenticated using (false);
drop policy if exists connect_audit_member_delete on public.connect_audit_logs;
create policy connect_audit_member_delete on public.connect_audit_logs for delete to authenticated using (false);

-- Role changes are enforced inside PostgreSQL, never trusted to the browser.
create or replace function public.connect_set_member_role(p_organization_id uuid,p_user_id uuid,p_new_role text)
returns void language plpgsql security definer set search_path=public as $
declare v_actor_role text;
declare v_target_role text;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select role into v_actor_role from public.connect_members where organization_id=p_organization_id and user_id=auth.uid();
 if v_actor_role not in ('owner','admin') then raise exception 'Only an owner or administrator can change roles'; end if;
 if p_new_role not in ('admin','manager','member','guest') then raise exception 'Invalid role'; end if;
 select role into v_target_role from public.connect_members where organization_id=p_organization_id and user_id=p_user_id;
 if v_target_role is null then raise exception 'Member not found'; end if;
 if v_target_role='owner' then raise exception 'The owner role cannot be changed here'; end if;
 if v_actor_role='admin' and p_new_role in ('admin') then raise exception 'Only the owner can appoint another administrator'; end if;
 update public.connect_members set role=p_new_role where organization_id=p_organization_id and user_id=p_user_id;
end $;
revoke all on function public.connect_set_member_role(uuid,uuid,text) from public,anon;
grant execute on function public.connect_set_member_role(uuid,uuid,text) to authenticated;

-- Private storage bucket for enterprise files. Existing bucket is not made public.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('connect-private-files','connect-private-files',false,52428800,
 array['application/pdf','image/png','image/jpeg','image/webp','text/plain','text/csv',
 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'])
on conflict(id) do update set public=false, file_size_limit=excluded.file_size_limit, allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists connect_storage_member_read on storage.objects;
create policy connect_storage_member_read on storage.objects for select to authenticated
using (bucket_id='connect-private-files' and exists(
 select 1 from public.connect_members m
 where m.user_id=auth.uid() and m.organization_id::text=split_part(name,'/',1)
));
drop policy if exists connect_storage_member_upload on storage.objects;
create policy connect_storage_member_upload on storage.objects for insert to authenticated
with check (bucket_id='connect-private-files' and exists(
 select 1 from public.connect_members m
 where m.user_id=auth.uid() and m.organization_id::text=split_part(name,'/',1)
));
drop policy if exists connect_storage_member_update on storage.objects;
create policy connect_storage_member_update on storage.objects for update to authenticated
using (bucket_id='connect-private-files' and exists(
 select 1 from public.connect_members m
 where m.user_id=auth.uid() and m.organization_id::text=split_part(name,'/',1)
))
with check (bucket_id='connect-private-files' and exists(
 select 1 from public.connect_members m
 where m.user_id=auth.uid() and m.organization_id::text=split_part(name,'/',1)
));
drop policy if exists connect_storage_manager_delete on storage.objects;
create policy connect_storage_manager_delete on storage.objects for delete to authenticated
using (bucket_id='connect-private-files' and exists(
 select 1 from public.connect_members m
 where m.user_id=auth.uid() and m.organization_id::text=split_part(name,'/',1) and m.role in ('owner','admin','manager')
));

-- Presence can be read by workspace members and only self-updated by the owner.
drop policy if exists connect_presence_self_write on public.connect_presence;
create policy connect_presence_self_write on public.connect_presence for all to authenticated
using (user_id=auth.uid() and public.connect_roadmap_is_org_member(organization_id))
with check (user_id=auth.uid() and public.connect_roadmap_is_org_member(organization_id));

-- Realtime refresh for presence and direct-message delivery/read receipts.
do $$
begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  begin alter publication supabase_realtime add table public.connect_presence; exception when duplicate_object then null; when others then if sqlstate <> '42710' then raise; end if; end;
  begin alter publication supabase_realtime add table public.connect_dm_participants; exception when duplicate_object then null; when others then if sqlstate <> '42710' then raise; end if; end;
 end if;
end $$;
