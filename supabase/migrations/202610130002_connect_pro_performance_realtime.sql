-- Connect Pro query and realtime performance improvements
create extension if not exists pg_trgm with schema extensions;
create index if not exists connect_messages_body_trgm_idx
  on public.connect_messages using gin (body extensions.gin_trgm_ops)
  where deleted_at is null;
create index if not exists connect_messages_channel_parent_created_idx
  on public.connect_messages(channel_id,parent_message_id,created_at desc)
  where deleted_at is null;
create index if not exists connect_reactions_message_idx
  on public.connect_message_reactions(message_id,emoji);
create index if not exists connect_notifications_unread_idx
  on public.connect_notifications(user_id,created_at desc)
  where read_at is null;
create index if not exists connect_push_subscriptions_user_idx
  on public.connect_push_subscriptions(user_id);
do $$
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    begin alter publication supabase_realtime add table public.connect_notifications;
    exception when duplicate_object then null; when others then
      if sqlstate <> '42710' then raise; end if;
    end;
  end if;
end $$;
