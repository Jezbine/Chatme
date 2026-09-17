-- Migration 007: WhatsApp-like group features
alter table public.conversations
  add column if not exists description text,
  add column if not exists only_admins_can_send boolean not null default false,
  add column if not exists only_admins_can_edit_info boolean not null default false;
