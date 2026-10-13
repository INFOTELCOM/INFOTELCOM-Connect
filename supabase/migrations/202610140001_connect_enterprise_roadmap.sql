-- INFOTELCOM Connect roadmap foundation: projects/tasks, direct messages, events, file organization, audit and presence.
create table if not exists public.connect_projects (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.connect_organizations(id) on delete cascade,
 name text not null check (char_length(trim(name)) between 2 and 120),
 description text not null default '',
 status text not null default 'active' check (status in ('active','paused','completed','archived')),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create table if not exists public.connect_tasks (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.connect_organizations(id) on delete cascade,
 project_id uuid references public.connect_projects(id) on delete set null,
 channel_id uuid references public.connect_channels(id) on delete set null,
 title text not null check (char_length(trim(title)) between 2 and 180),
 description text not null default '',
 status text not null default 'todo' check (status in ('todo','in_progress','blocked','done')),
 priority text not null default 'medium' check (priority in ('low','medium','high','urgent')),
 assigned_to uuid references auth.users(id) on delete set null,
 created_by uuid not null references auth.users(id),
 due_at timestamptz,
 completed_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists connect_tasks_org_status_due_idx on public.connect_tasks(organization_id,status,due_at);
create index if not exists connect_tasks_assignee_idx on public.connect_tasks(assigned_to,status,due_at);
create table if not exists public.connect_dm_conversations (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.connect_organizations(id) on delete cascade,
 title text,
 is_group boolean not null default false,
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists public.connect_dm_participants (
 conversation_id uuid not null references public.connect_dm_conversations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 last_read_at timestamptz,
 joined_at timestamptz not null default now(),
 primary key(conversation_id,user_id)
);
create table if not exists public.connect_dm_messages (
 id uuid primary key default gen_random_uuid(),
 conversation_id uuid not null references public.connect_dm_conversations(id) on delete cascade,
 sender_id uuid not null references auth.users(id) on delete cascade,
 body text not null check (char_length(trim(body)) between 1 and 10000),
 attachment_path text,
 created_at timestamptz not null default now(),
 edited_at timestamptz,
 deleted_at timestamptz
);
create index if not exists connect_dm_messages_conversation_created_idx on public.connect_dm_messages(conversation_id,created_at desc);
create table if not exists public.connect_calendar_events (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.connect_organizations(id) on delete cascade,
 meeting_id uuid references public.connect_meetings(id) on delete set null,
 title text not null check (char_length(trim(title)) between 2 and 160),
 description text not null default '',
 starts_at timestamptz not null,
 ends_at timestamptz not null,
 timezone text not null default 'Europe/Paris',
 location text,
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 check (ends_at > starts_at)
);
create index if not exists connect_calendar_org_start_idx on public.connect_calendar_events(organization_id,starts_at);
create table if not exists public.connect_file_folders (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.connect_organizations(id) on delete cascade,
 parent_id uuid references public.connect_file_folders(id) on delete cascade,
 name text not null check (char_length(trim(name)) between 1 and 120),
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);
create table if not exists public.connect_file_versions (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.connect_organizations(id) on delete cascade,
 storage_path text not null,
 original_name text not null,
 version_number integer not null default 1 check (version_number > 0),
 size_bytes bigint not null default 0 check (size_bytes >= 0),
 mime_type text not null default 'application/octet-stream',
 uploaded_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 unique(storage_path,version_number)
);
create table if not exists public.connect_file_shares (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.connect_organizations(id) on delete cascade,
 storage_path text not null,
 created_by uuid not null references auth.users(id),
 token_hash text not null unique,
 expires_at timestamptz not null,
 revoked_at timestamptz,
 created_at timestamptz not null default now()
);
create table if not exists public.connect_audit_logs (
 id bigint generated always as identity primary key,
 organization_id uuid not null references public.connect_organizations(id) on delete cascade,
 actor_id uuid references auth.users(id) on delete set null,
 action text not null,
 resource_type text not null,
 resource_id text,
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create index if not exists connect_audit_org_created_idx on public.connect_audit_logs(organization_id,created_at desc);
create table if not exists public.connect_presence (
 organization_id uuid not null references public.connect_organizations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 status text not null default 'online' check (status in ('online','away','busy','offline')),
 status_text text not null default '',
 last_seen_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 primary key(organization_id,user_id)
);

-- Shared membership predicates keep data isolated between workspaces.
create or replace function public.connect_roadmap_is_org_member(p_org uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.connect_members m where m.organization_id=p_org and m.user_id=auth.uid())
$$;
create or replace function public.connect_roadmap_is_org_manager(p_org uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.connect_members m where m.organization_id=p_org and m.user_id=auth.uid() and m.role in ('owner','admin','manager'))
$$;
create or replace function public.connect_roadmap_is_dm_participant(p_conversation uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.connect_dm_participants p where p.conversation_id=p_conversation and p.user_id=auth.uid())
$$;

alter table public.connect_projects enable row level security;
alter table public.connect_tasks enable row level security;
alter table public.connect_dm_conversations enable row level security;
alter table public.connect_dm_participants enable row level security;
alter table public.connect_dm_messages enable row level security;
alter table public.connect_calendar_events enable row level security;
alter table public.connect_file_folders enable row level security;
alter table public.connect_file_versions enable row level security;
alter table public.connect_file_shares enable row level security;
alter table public.connect_audit_logs enable row level security;
alter table public.connect_presence enable row level security;

drop policy if exists connect_projects_member_select on public.connect_projects;
create policy connect_projects_member_select on public.connect_projects for select to authenticated using (public.connect_roadmap_is_org_member(organization_id));
drop policy if exists connect_projects_manager_write on public.connect_projects;
create policy connect_projects_manager_write on public.connect_projects for all to authenticated using (public.connect_roadmap_is_org_manager(organization_id)) with check (public.connect_roadmap_is_org_manager(organization_id));
drop policy if exists connect_tasks_member_select on public.connect_tasks;
create policy connect_tasks_member_select on public.connect_tasks for select to authenticated using (public.connect_roadmap_is_org_member(organization_id));
drop policy if exists connect_tasks_member_insert on public.connect_tasks;
create policy connect_tasks_member_insert on public.connect_tasks for insert to authenticated with check (public.connect_roadmap_is_org_member(organization_id) and created_by=auth.uid());
drop policy if exists connect_tasks_manager_update on public.connect_tasks;
create policy connect_tasks_manager_update on public.connect_tasks for update to authenticated using (public.connect_roadmap_is_org_manager(organization_id) or assigned_to=auth.uid() or created_by=auth.uid()) with check (public.connect_roadmap_is_org_member(organization_id));
drop policy if exists connect_tasks_manager_delete on public.connect_tasks;
create policy connect_tasks_manager_delete on public.connect_tasks for delete to authenticated using (public.connect_roadmap_is_org_manager(organization_id) or created_by=auth.uid());

drop policy if exists connect_dm_conversations_participant_select on public.connect_dm_conversations;
create policy connect_dm_conversations_participant_select on public.connect_dm_conversations for select to authenticated using (public.connect_roadmap_is_org_member(organization_id) and public.connect_roadmap_is_dm_participant(id));
drop policy if exists connect_dm_conversations_member_insert on public.connect_dm_conversations;
create policy connect_dm_conversations_member_insert on public.connect_dm_conversations for insert to authenticated with check (public.connect_roadmap_is_org_member(organization_id) and created_by=auth.uid());
drop policy if exists connect_dm_participants_select on public.connect_dm_participants;
create policy connect_dm_participants_select on public.connect_dm_participants for select to authenticated using (user_id=auth.uid() or public.connect_roadmap_is_dm_participant(conversation_id));
drop policy if exists connect_dm_participants_insert on public.connect_dm_participants;
create policy connect_dm_participants_insert on public.connect_dm_participants for insert to authenticated with check (public.connect_roadmap_is_org_member((select organization_id from public.connect_dm_conversations where id=conversation_id)) and (user_id=auth.uid() or public.connect_roadmap_is_org_manager((select organization_id from public.connect_dm_conversations where id=conversation_id))));
drop policy if exists connect_dm_messages_participant_select on public.connect_dm_messages;
create policy connect_dm_messages_participant_select on public.connect_dm_messages for select to authenticated using (public.connect_roadmap_is_dm_participant(conversation_id));
drop policy if exists connect_dm_messages_participant_insert on public.connect_dm_messages;
create policy connect_dm_messages_participant_insert on public.connect_dm_messages for insert to authenticated with check (sender_id=auth.uid() and public.connect_roadmap_is_dm_participant(conversation_id));
drop policy if exists connect_dm_messages_sender_update on public.connect_dm_messages;
create policy connect_dm_messages_sender_update on public.connect_dm_messages for update to authenticated using (sender_id=auth.uid() and public.connect_roadmap_is_dm_participant(conversation_id)) with check (sender_id=auth.uid());
drop policy if exists connect_calendar_member_select on public.connect_calendar_events;
create policy connect_calendar_member_select on public.connect_calendar_events for select to authenticated using (public.connect_roadmap_is_org_member(organization_id));
drop policy if exists connect_calendar_member_insert on public.connect_calendar_events;
create policy connect_calendar_member_insert on public.connect_calendar_events for insert to authenticated with check (public.connect_roadmap_is_org_member(organization_id) and created_by=auth.uid());
drop policy if exists connect_calendar_member_update on public.connect_calendar_events;
create policy connect_calendar_member_update on public.connect_calendar_events for update to authenticated using (public.connect_roadmap_is_org_member(organization_id)) with check (public.connect_roadmap_is_org_member(organization_id));
drop policy if exists connect_calendar_manager_delete on public.connect_calendar_events;
create policy connect_calendar_manager_delete on public.connect_calendar_events for delete to authenticated using (public.connect_roadmap_is_org_manager(organization_id) or created_by=auth.uid());
drop policy if exists connect_file_folders_member_all on public.connect_file_folders;
create policy connect_file_folders_member_all on public.connect_file_folders for all to authenticated using (public.connect_roadmap_is_org_member(organization_id)) with check (public.connect_roadmap_is_org_member(organization_id) and created_by=auth.uid());
drop policy if exists connect_file_versions_member_select on public.connect_file_versions;
create policy connect_file_versions_member_select on public.connect_file_versions for select to authenticated using (public.connect_roadmap_is_org_member(organization_id));
drop policy if exists connect_file_versions_member_insert on public.connect_file_versions;
create policy connect_file_versions_member_insert on public.connect_file_versions for insert to authenticated with check (public.connect_roadmap_is_org_member(organization_id) and uploaded_by=auth.uid());
drop policy if exists connect_file_shares_member_select on public.connect_file_shares;
create policy connect_file_shares_member_select on public.connect_file_shares for select to authenticated using (public.connect_roadmap_is_org_member(organization_id) and created_by=auth.uid());
drop policy if exists connect_file_shares_manager_all on public.connect_file_shares;
create policy connect_file_shares_manager_all on public.connect_file_shares for all to authenticated using (public.connect_roadmap_is_org_manager(organization_id)) with check (public.connect_roadmap_is_org_manager(organization_id) and created_by=auth.uid());
drop policy if exists connect_audit_manager_select on public.connect_audit_logs;
create policy connect_audit_manager_select on public.connect_audit_logs for select to authenticated using (public.connect_roadmap_is_org_manager(organization_id));
drop policy if exists connect_audit_member_insert on public.connect_audit_logs;
create policy connect_audit_member_insert on public.connect_audit_logs for insert to authenticated with check (public.connect_roadmap_is_org_member(organization_id) and actor_id=auth.uid());
drop policy if exists connect_presence_member_select on public.connect_presence;
create policy connect_presence_member_select on public.connect_presence for select to authenticated using (public.connect_roadmap_is_org_member(organization_id));
drop policy if exists connect_presence_self_write on public.connect_presence;
create policy connect_presence_self_write on public.connect_presence for all to authenticated using (user_id=auth.uid() and public.connect_roadmap_is_org_member(organization_id)) with check (user_id=auth.uid() and public.connect_roadmap_is_org_member(organization_id));

-- Record privileged membership changes in the audit log.
create or replace function public.connect_audit_membership_change()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if tg_op='DELETE' then
  insert into public.connect_audit_logs(organization_id,actor_id,action,resource_type,resource_id,metadata)
  values(old.organization_id,auth.uid(),'DELETE','membership',old.user_id::text,jsonb_build_object('old_role',old.role));
  return old;
 else
  insert into public.connect_audit_logs(organization_id,actor_id,action,resource_type,resource_id,metadata)
  values(new.organization_id,auth.uid(),tg_op,'membership',new.user_id::text,jsonb_build_object('new_role',new.role));
  return new;
 end if;
end $$;
drop trigger if exists connect_members_audit_trigger on public.connect_members;
create trigger connect_members_audit_trigger after insert or update or delete on public.connect_members
for each row execute function public.connect_audit_membership_change();

-- Indexes and realtime for collaboration screens.
create index if not exists connect_dm_participants_user_idx on public.connect_dm_participants(user_id,conversation_id);
do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  begin alter publication supabase_realtime add table public.connect_tasks; exception when duplicate_object then null; when others then if sqlstate <> '42710' then raise; end if; end;
  begin alter publication supabase_realtime add table public.connect_dm_messages; exception when duplicate_object then null; when others then if sqlstate <> '42710' then raise; end if; end;
  begin alter publication supabase_realtime add table public.connect_calendar_events; exception when duplicate_object then null; when others then if sqlstate <> '42710' then raise; end if; end;
 end if;
end $$;
