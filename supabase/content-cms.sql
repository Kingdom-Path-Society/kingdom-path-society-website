-- Kingdom Path Society Content CMS
-- Run this in the Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.content_posts (
  id uuid primary key default gen_random_uuid(),
  type text not null default 'Sermon',
  title_en text not null,
  title_ti text,
  summary_en text,
  summary_ti text,
  content_en text,
  content_ti text,
  video_url text,
  audio_url text,
  image_url text,
  published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.content_posts enable row level security;

drop policy if exists "Public can read published content" on public.content_posts;
create policy "Public can read published content"
on public.content_posts
for select
using (published = true or auth.role() = 'authenticated');

drop policy if exists "Authenticated users can insert content" on public.content_posts;
create policy "Authenticated users can insert content"
on public.content_posts
for insert
to authenticated
with check (true);

drop policy if exists "Authenticated users can update content" on public.content_posts;
create policy "Authenticated users can update content"
on public.content_posts
for update
to authenticated
using (true)
with check (true);

drop policy if exists "Authenticated users can delete content" on public.content_posts;
create policy "Authenticated users can delete content"
on public.content_posts
for delete
to authenticated
using (true);

insert into storage.buckets (id, name, public)
values ('content-media', 'content-media', true)
on conflict (id) do update set public = true;

drop policy if exists "Public content media read" on storage.objects;
create policy "Public content media read"
on storage.objects
for select
using (bucket_id = 'content-media');

drop policy if exists "Authenticated content media upload" on storage.objects;
create policy "Authenticated content media upload"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'content-media');

drop policy if exists "Authenticated content media update" on storage.objects;
create policy "Authenticated content media update"
on storage.objects
for update
to authenticated
using (bucket_id = 'content-media');

drop policy if exists "Authenticated content media delete" on storage.objects;
create policy "Authenticated content media delete"
on storage.objects
for delete
to authenticated
using (bucket_id = 'content-media');

-- In Supabase Authentication settings, disable public sign-ups
-- if only your staff should use the admin portal.