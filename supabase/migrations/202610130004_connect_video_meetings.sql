create table if not exists public.connect_meetings (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.connect_organizations(id) on delete cascade,
 created_by uuid not null references auth.users(id) on delete cascade,
 title text not null check (char_length(title) between 2 and 120),
 room_name text not null unique,
 meeting_url text not null,
 scheduled_at timestamptz,
 created_at timestamptz not null default now()
);
create index if not exists connect_meetings_org_created_idx on public.connect_meetings(organization_id,created_at desc);
alter table public.connect_meetings enable row level security;
drop policy if exists connect_meetings_read_member on public.connect_meetings;
create policy connect_meetings_read_member on public.connect_meetings for select to authenticated
using (exists(select 1 from public.connect_members m where m.organization_id=connect_meetings.organization_id and m.user_id=auth.uid()));
drop policy if exists connect_meetings_create_member on public.connect_meetings;
create policy connect_meetings_create_member on public.connect_meetings for insert to authenticated
with check (created_by=auth.uid() and exists(select 1 from public.connect_members m where m.organization_id=connect_meetings.organization_id and m.user_id=auth.uid()));
drop policy if exists connect_meetings_delete_creator_or_admin on public.connect_meetings;
create policy connect_meetings_delete_creator_or_admin on public.connect_meetings for delete to authenticated
using (created_by=auth.uid() or exists(select 1 from public.connect_members m where m.organization_id=connect_meetings.organization_id and m.user_id=auth.uid() and m.role in ('owner','admin')));
grant select,insert,delete on public.connect_meetings to authenticated;