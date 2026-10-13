-- INFOTELCOM Connect Pro collaboration features
-- Run once in Supabase SQL Editor before enabling these controls.
create table if not exists public.connect_message_reactions (
 id uuid primary key default gen_random_uuid(),
 message_id uuid not null references public.connect_messages(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 emoji text not null check (emoji in ('👍','❤️','😂','👏')),
 created_at timestamptz not null default now(),
 unique(message_id,user_id,emoji)
);
create table if not exists public.connect_message_pins (
 id uuid primary key default gen_random_uuid(),
 message_id uuid not null references public.connect_messages(id) on delete cascade,
 channel_id uuid not null references public.connect_channels(id) on delete cascade,
 pinned_by uuid not null references auth.users(id) on delete cascade,
 created_at timestamptz not null default now(),
 unique(message_id)
);
alter table public.connect_messages add column if not exists parent_message_id uuid references public.connect_messages(id) on delete cascade;
create index if not exists connect_messages_parent_idx on public.connect_messages(parent_message_id);
create index if not exists connect_messages_channel_created_idx on public.connect_messages(channel_id,created_at desc);
create table if not exists public.connect_notifications (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 organization_id uuid not null references public.connect_organizations(id) on delete cascade,
 channel_id uuid references public.connect_channels(id) on delete cascade,
 message_id uuid references public.connect_messages(id) on delete cascade,
 kind text not null default 'message',
 title text not null,
 body text not null default '',
 read_at timestamptz,
 created_at timestamptz not null default now()
);
create index if not exists connect_notifications_user_created_idx on public.connect_notifications(user_id,created_at desc);
create table if not exists public.connect_push_subscriptions (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 endpoint text not null unique,
 subscription jsonb not null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.connect_message_reactions enable row level security;
alter table public.connect_message_pins enable row level security;
alter table public.connect_notifications enable row level security;
alter table public.connect_push_subscriptions enable row level security;
drop policy if exists "workspace members read reactions" on public.connect_message_reactions;
create policy "workspace members read reactions" on public.connect_message_reactions for select to authenticated using (exists(select 1 from public.connect_messages m join public.connect_channels c on c.id=m.channel_id join public.connect_members cm on cm.organization_id=c.organization_id where m.id=message_id and cm.user_id=auth.uid()));
drop policy if exists "members add own reactions" on public.connect_message_reactions;
create policy "members add own reactions" on public.connect_message_reactions for insert to authenticated with check (user_id=auth.uid() and exists(select 1 from public.connect_messages m join public.connect_channels c on c.id=m.channel_id join public.connect_members cm on cm.organization_id=c.organization_id where m.id=message_id and cm.user_id=auth.uid()));
drop policy if exists "members remove own reactions" on public.connect_message_reactions;
create policy "members remove own reactions" on public.connect_message_reactions for delete to authenticated using (user_id=auth.uid());
drop policy if exists "workspace members read pins" on public.connect_message_pins;
create policy "workspace members read pins" on public.connect_message_pins for select to authenticated using (exists(select 1 from public.connect_channels c join public.connect_members cm on cm.organization_id=c.organization_id where c.id=channel_id and cm.user_id=auth.uid()));
drop policy if exists "workspace members pin messages" on public.connect_message_pins;
create policy "workspace members pin messages" on public.connect_message_pins for insert to authenticated with check (pinned_by=auth.uid() and exists(select 1 from public.connect_channels c join public.connect_members cm on cm.organization_id=c.organization_id where c.id=channel_id and cm.user_id=auth.uid()));
drop policy if exists "workspace members unpin messages" on public.connect_message_pins;
create policy "workspace members unpin messages" on public.connect_message_pins for delete to authenticated using (exists(select 1 from public.connect_channels c join public.connect_members cm on cm.organization_id=c.organization_id where c.id=channel_id and cm.user_id=auth.uid()));
drop policy if exists "users read own notifications" on public.connect_notifications;
create policy "users read own notifications" on public.connect_notifications for select to authenticated using (user_id=auth.uid());
drop policy if exists "users update own notifications" on public.connect_notifications;
create policy "users update own notifications" on public.connect_notifications for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
drop policy if exists "users manage own push subscriptions" on public.connect_push_subscriptions;
create policy "users manage own push subscriptions" on public.connect_push_subscriptions for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
-- Notification history for each workspace member when a new message is posted.
create or replace function public.connect_notify_channel_message()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_org uuid; v_name text;
begin
 select organization_id,name into v_org,v_name from public.connect_channels where id=new.channel_id;
 if v_org is null then return new; end if;
 insert into public.connect_notifications(user_id,organization_id,channel_id,message_id,kind,title,body)
 select cm.user_id,v_org,new.channel_id,new.id,'message','Nouveau message dans #'||coalesce(v_name,'canal'),left(coalesce(new.body,''),180)
 from public.connect_members cm
 where cm.organization_id=v_org and cm.user_id<>new.sender_id;
 return new;
end; $$;
drop trigger if exists connect_message_notification_trigger on public.connect_messages;
create trigger connect_message_notification_trigger after insert on public.connect_messages for each row execute function public.connect_notify_channel_message();
