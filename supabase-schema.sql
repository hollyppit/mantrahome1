-- ============================================================
-- 만트라 스튜디오 포트폴리오 사이트 — Supabase 스키마
-- ============================================================
-- 실행: Supabase Dashboard → SQL Editor → 새 쿼리 → 전체 붙여넣기 실행
-- ============================================================

-- 1. 사이트 전역 설정
create table if not exists public.studio_settings (
  id int primary key default 1,
  studio_name text default '만트라 스튜디오',
  studio_tagline text default 'MANTRA STUDIO',
  studio_description text default '전주 기반 1인 창작 스튜디오. 웹툰, AI 도구, 인디 서비스를 만듭니다.',
  hero_headline text default 'We make bold\nstories & tools.',
  hero_subline text default '이야기와 기술이 만나는 자리에서, 작고 단단한 것들을 만듭니다.',
  hero_image_url text,
  about_title text default 'ABOUT',
  about_body text default '만트라 스튜디오는 웹툰 작가이자 개발자인 릴매(백진우)의 1인 창작 스튜디오입니다.\n\n이야기, 이미지, 코드가 만나는 지점에서 브랜드와 도구를 만듭니다.',
  about_image_url text,
  logo_url text,
  favicon_url text,
  contact_email text default 'hello@mantrastudio.kr',
  contact_location text default '전주, 대한민국',
  social_instagram text,
  social_youtube text,
  social_twitter text,
  social_github text,
  footer_copyright text default '© MANTRA STUDIO. ALL RIGHTS RESERVED.',
  seo_description text default '전주 기반 1인 창작 스튜디오 · 웹툰과 AI 도구',
  theme_bg text default '#f5f3ee',
  theme_fg text default '#111111',
  theme_accent text default '#d94b2b',
  updated_at timestamptz default now(),
  constraint single_row check (id = 1)
);
insert into public.studio_settings (id) values (1) on conflict (id) do nothing;

-- 2. 카테고리 (포트폴리오 필터)
create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,      -- webtoon, product, service, experiment
  label text not null,            -- WEBTOON, PRODUCT
  description text,
  sort_order int default 0,
  created_at timestamptz default now()
);

-- 3. 포트폴리오 프로젝트
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text,                  -- 한 줄 설명
  description text,               -- 긴 설명 (상세 모달)
  category_id uuid references public.categories(id) on delete set null,
  year text,                      -- "2024", "2024–2025"
  client text,                    -- 클라이언트/플랫폼 (KakaoPage, Netflix 등)
  role text,                      -- 맡은 역할 (기획·작화·개발)
  tech text,                      -- 사용 기술 스택/도구 (쉼표 구분)
  thumbnail_url text,             -- 카드 썸네일
  gallery jsonb default '[]'::jsonb,   -- 상세 이미지 배열 [{url, caption}]
  link_label text,                -- "바로가기", "연재 페이지"
  link_url text,
  is_featured boolean default false,   -- 상단 하이라이트
  is_visible boolean default true,
  sort_order int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index if not exists projects_cat_idx on public.projects (category_id, sort_order);
create index if not exists projects_featured_idx on public.projects (is_featured, sort_order);

-- 4. 서비스/제공 목록 (About 섹션 아래 "무엇을 하는가")
create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  icon text,                      -- 이모지 또는 짧은 텍스트 마크
  sort_order int default 0,
  is_visible boolean default true,
  created_at timestamptz default now()
);

-- 5. 타임라인 / 이력 (선택)
create table if not exists public.timeline_entries (
  id uuid primary key default gen_random_uuid(),
  year text not null,
  title text not null,
  description text,
  sort_order int default 0,
  is_visible boolean default true,
  created_at timestamptz default now()
);

-- 6. updated_at 트리거
create or replace function public.touch_updated_at()
returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

drop trigger if exists trg_studio_touch on public.studio_settings;
create trigger trg_studio_touch before update on public.studio_settings
  for each row execute procedure public.touch_updated_at();

drop trigger if exists trg_projects_touch on public.projects;
create trigger trg_projects_touch before update on public.projects
  for each row execute procedure public.touch_updated_at();

-- 7. RLS
alter table public.studio_settings enable row level security;
alter table public.categories      enable row level security;
alter table public.projects        enable row level security;
alter table public.services        enable row level security;
alter table public.timeline_entries enable row level security;

-- 공개 읽기
drop policy if exists "public read studio_settings" on public.studio_settings;
create policy "public read studio_settings" on public.studio_settings
  for select to anon, authenticated using (true);

drop policy if exists "public read categories" on public.categories;
create policy "public read categories" on public.categories
  for select to anon, authenticated using (true);

drop policy if exists "public read projects" on public.projects;
create policy "public read projects" on public.projects
  for select to anon, authenticated using (is_visible = true);

drop policy if exists "public read services" on public.services;
create policy "public read services" on public.services
  for select to anon, authenticated using (is_visible = true);

drop policy if exists "public read timeline" on public.timeline_entries;
create policy "public read timeline" on public.timeline_entries
  for select to anon, authenticated using (is_visible = true);

-- 인증된 관리자 전체 권한
drop policy if exists "auth all studio_settings" on public.studio_settings;
create policy "auth all studio_settings" on public.studio_settings
  for all to authenticated using (true) with check (true);

drop policy if exists "auth all categories" on public.categories;
create policy "auth all categories" on public.categories
  for all to authenticated using (true) with check (true);

drop policy if exists "auth all projects" on public.projects;
create policy "auth all projects" on public.projects
  for all to authenticated using (true) with check (true);

drop policy if exists "auth all services" on public.services;
create policy "auth all services" on public.services
  for all to authenticated using (true) with check (true);

drop policy if exists "auth all timeline" on public.timeline_entries;
create policy "auth all timeline" on public.timeline_entries
  for all to authenticated using (true) with check (true);

-- 관리자 전체 조회 (숨김 포함)
drop policy if exists "auth read all projects" on public.projects;
create policy "auth read all projects" on public.projects
  for select to authenticated using (true);

drop policy if exists "auth read all services" on public.services;
create policy "auth read all services" on public.services
  for select to authenticated using (true);

drop policy if exists "auth read all timeline" on public.timeline_entries;
create policy "auth read all timeline" on public.timeline_entries
  for select to authenticated using (true);

-- 8. 초기 카테고리 샘플 (원하는 경우 주석 해제)
-- insert into public.categories (slug, label, sort_order) values
--   ('all',     'ALL',      0),
--   ('webtoon', 'WEBTOON',  1),
--   ('product', 'PRODUCT',  2),
--   ('service', 'SERVICE',  3),
--   ('experiment','EXPERIMENT', 4);
