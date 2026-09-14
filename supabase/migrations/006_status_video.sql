-- 006_status_video.sql - Permet le type video pour statuts (Meta/WeChat : stories vidéo)
-- Ancienne contrainte: check (type in ('text','image')) -> bloquait les vidéos

do $$ begin
  -- Supprimer ancienne contrainte si existe (nom auto-généré)
  alter table public.statuses drop constraint if exists statuses_type_check;
exception when others then null;
end $$;

alter table public.statuses add constraint statuses_type_check check (type in ('text','image','video'));

-- Commentaire
comment on column public.statuses.type is 'text | image | video - video supporté depuis 006';
