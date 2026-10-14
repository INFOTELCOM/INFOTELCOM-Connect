-- Chat attachments and assigned tasks. Safe to apply repeatedly.
create table if not exists public.connect_dm_attachments (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.connect_organizations(id) on delete cascade,
 conversation_id uuid not null references public.connect_dm_conversations(id) on delete cascade,
 uploaded_by uuid not null references auth.users(id) on delete cascade,
 storage_path text not null unique,
 original_name text not null,
 mime_type text not null default 'application/octet-stream',
 size_bytes bigint not null check(size_bytes>=0 and size_bytes<=52428800),
 created_at timestamptz not null default now()
);
create index if not exists connect_dm_attachments_conversation_created_idx on public.connect_dm_attachments(conversation_id,created_at desc);
alter table public.connect_dm_attachments enable row level security;
drop policy if exists connect_dm_attachments_member_read on public.connect_dm_attachments;
create policy connect_dm_attachments_member_read on public.connect_dm_attachments for select to authenticated
using (exists(select 1 from public.connect_dm_participants p join public.connect_dm_conversations c on c.id=p.conversation_id where p.conversation_id=connect_dm_attachments.conversation_id and p.user_id=auth.uid() and c.organization_id=connect_dm_attachments.organization_id));
drop policy if exists connect_dm_attachments_member_insert on public.connect_dm_attachments;
create policy connect_dm_attachments_member_insert on public.connect_dm_attachments for insert to authenticated
with check (uploaded_by=auth.uid() and exists(select 1 from public.connect_dm_participants p join public.connect_dm_conversations c on c.id=p.conversation_id where p.conversation_id=connect_dm_attachments.conversation_id and p.user_id=auth.uid() and c.organization_id=connect_dm_attachments.organization_id));

create table if not exists public.connect_tasks (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.connect_organizations(id) on delete cascade,
 title text not null check(length(trim(title)) between 1 and 180),
 description text,
 assigned_to uuid references auth.users(id) on delete set null,
 created_by uuid not null references auth.users(id) on delete cascade,
 status text not null default 'todo' check(status in ('todo','in_progress','done')),
 due_at timestamptz,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists connect_tasks_org_status_created_idx on public.connect_tasks(organization_id,status,created_at desc);
alter table public.connect_tasks enable row level security;
drop policy if exists connect_tasks_member_read on public.connect_tasks;
create policy connect_tasks_member_read on public.connect_tasks for select to authenticated
using(exists(select 1 from public.connect_members m where m.organization_id=connect_tasks.organization_id and m.user_id=auth.uid()));
drop policy if exists connect_tasks_member_create on public.connect_tasks;
create policy connect_tasks_member_create on public.connect_tasks for insert to authenticated
with check(created_by=auth.uid() and exists(select 1 from public.connect_members m where m.organization_id=connect_tasks.organization_id and m.user_id=auth.uid()));
drop policy if exists connect_tasks_member_update on public.connect_tasks;
create policy connect_tasks_member_update on public.connect_tasks for update to authenticated
using(exists(select 1 from public.connect_members m where m.organization_id=connect_tasks.organization_id and m.user_id=auth.uid()))
with check(exists(select 1 from public.connect_members m where m.organization_id=connect_tasks.organization_id and m.user_id=auth.uid()) and (assigned_to is null or exists(select 1 from public.connect_members m where m.organization_id=connect_tasks.organization_id and m.user_id=connect_tasks.assigned_to)));
