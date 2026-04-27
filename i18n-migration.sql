-- ============================================================
-- 만트라 스튜디오 — 한/영 다국어(i18n) 마이그레이션
-- ============================================================
-- 실행 방법: Supabase Dashboard → SQL Editor → 새 쿼리 → 아래 전체 붙여넣기 실행
-- 기존 데이터 보존: 안전한 ADD COLUMN IF NOT EXISTS만 사용합니다.
-- ============================================================

-- 1) studio_settings: 사이트 전역 텍스트의 영문 버전
alter table public.studio_settings
  add column if not exists studio_name_en        text,
  add column if not exists studio_tagline_en     text,
  add column if not exists studio_description_en text,
  add column if not exists hero_headline_en      text,
  add column if not exists hero_subline_en       text,
  add column if not exists about_title_en        text,
  add column if not exists about_body_en         text,
  add column if not exists contact_location_en   text,
  add column if not exists footer_copyright_en   text,
  add column if not exists seo_description_en    text;

-- 2) categories: 영문 라벨
alter table public.categories
  add column if not exists label_en       text,
  add column if not exists description_en text;

-- 3) projects: 카드 + 상세 모달의 영문 콘텐츠
alter table public.projects
  add column if not exists title_en       text,
  add column if not exists subtitle_en    text,
  add column if not exists description_en text,
  add column if not exists client_en      text,
  add column if not exists role_en        text,
  add column if not exists tech_en        text,
  add column if not exists link_label_en  text;

-- 4) services: "What we do" 카드의 영문
alter table public.services
  add column if not exists title_en       text,
  add column if not exists description_en text;

-- 5) timeline_entries: 연혁의 영문
alter table public.timeline_entries
  add column if not exists title_en       text,
  add column if not exists description_en text;

-- ============================================================
-- 끝. 기존 한글 컬럼은 그대로 유지되고, *_en 컬럼이 비어있으면
-- 사이트는 자동으로 한글 값으로 폴백합니다.
-- ============================================================
