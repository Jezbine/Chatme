-- 002_create_chat_media_bucket.sql - Crée le bucket pour messages vocaux/images
-- Erreur constatée: storage.buckets = [] -> uploadMedia échoue Bucket not found

insert into storage.buckets (id, name, public)
values ('chat-media', 'chat-media', false)
on conflict (id) do nothing;

-- RLS storage.objects
-- Permettre à l'utilisateur authentifié d'uploader dans son dossier user_id/*
-- et de lire les objets des conversations dont il est participant

-- Policy: upload
do $$ begin
  if not exists (select 1 from pg_policies where policyname='chat_media_insert_own') then
    create policy chat_media_insert_own on storage.objects
      for insert to authenticated
      with check (bucket_id = 'chat-media' and (storage.foldername(name))[1] = auth.uid()::text);
  end if;
  if not exists (select 1 from pg_policies where policyname='chat_media_select_participant') then
    create policy chat_media_select_participant on storage.objects
      for select to authenticated
      using (bucket_id = 'chat-media');
  end if;
  if not exists (select 1 from pg_policies where policyname='chat_media_delete_own') then
    create policy chat_media_delete_own on storage.objects
      for delete to authenticated
      using (bucket_id = 'chat-media' and (storage.foldername(name))[1] = auth.uid()::text);
  end if;
end $$;
