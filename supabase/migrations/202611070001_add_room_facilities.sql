-- Add a free-text facilities field to each room.
alter table public.rooms
  add column if not exists facilities text;
