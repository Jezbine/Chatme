-- 001_fix_mark_messages_as_read.sql - Corrige l'ambiguïté conversation_id + 42P13 rename
-- Erreur constatée: column reference "conversation_id" is ambiguous (code 42702)

drop function if exists public.mark_messages_as_read(uuid,uuid);
create function public.mark_messages_as_read(p_conversation_id uuid, p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then raise exception 'Non authentifié'; end if;

  -- Met à jour le last_read_message_id du participant courant
  update public.conversation_participants
  set last_read_message_id = p_message_id
  where conversation_participants.conversation_id = p_conversation_id
    and conversation_participants.user_id = v_user_id;

  -- Marque les messages comme lus (si colonne status existe)
  -- On ne touche que les messages de cette conversation, envoyés par d'autres
  update public.messages
  set status = 'read'
  where messages.conversation_id = p_conversation_id
    and messages.sender_id != v_user_id
    and messages.created_at <= (select created_at from public.messages where id = p_message_id)
    and messages.status != 'read';
end;
$$;

grant execute on function public.mark_messages_as_read(uuid, uuid) to authenticated;
