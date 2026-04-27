-- ============================================================
-- 만트라 스튜디오 포트폴리오 샘플 데이터 (1회 실행)
-- ============================================================
-- Supabase Dashboard → SQL Editor → 새 쿼리 → 전체 붙여넣기 → Run
-- 관리자 페이지에서 텍스트/이미지만 교체하면 실제 포트폴리오가 됩니다.
-- (주의) 기존 카테고리/프로젝트/서비스/타임라인을 모두 지우고 새로 넣습니다.
-- ============================================================

begin;

delete from public.projects;
delete from public.categories;
delete from public.services;
delete from public.timeline_entries;

-- 1) 사이트 전역 설정 (테라코타 + 아이보리)
update public.studio_settings
set studio_name        = coalesce(nullif(studio_name,''), '만트라 스튜디오'),
    studio_tagline     = coalesce(nullif(studio_tagline,''), 'MANTRA STUDIO'),
    studio_description = '전주 기반 1인 창작 스튜디오 · 웹툰과 AI 도구',
    hero_headline      = E'We make bold\nstories & tools.',
    hero_subline       = '이야기와 기술이 만나는 자리에서, 작고 단단한 것들을 만듭니다.',
    hero_image_url     = 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1400&q=80',
    about_body         = E'만트라 스튜디오는 웹툰 작가이자 개발자인 릴매(백진우)의 1인 창작 스튜디오입니다.\n\n이야기, 이미지, 코드가 만나는 지점에서 브랜드와 도구를 만듭니다. 크기가 아닌 밀도로 승부하며, 한 번의 좋은 선택이 열 개의 평범함을 이긴다고 믿습니다.',
    about_image_url    = 'https://images.unsplash.com/photo-1499951360447-b19be8fe80f5?w=1000&q=80',
    contact_email      = 'hello@mantrastudio.kr',
    contact_location   = '전주, 대한민국',
    social_instagram   = 'https://instagram.com/mantra.studio',
    social_youtube     = 'https://youtube.com/@mantrastudio',
    social_twitter     = 'https://twitter.com/mantrastudio',
    social_github      = 'https://github.com/mantrastudio',
    footer_copyright   = '© MANTRA STUDIO. ALL RIGHTS RESERVED.',
    seo_description    = '전주 기반 1인 창작 스튜디오 · 웹툰과 AI 도구',
    theme_bg           = '#f5f3ee',
    theme_fg           = '#111111',
    theme_accent       = '#d94b2b'
where id = 1;

-- 2) 카테고리
insert into public.categories (slug, label, description, sort_order) values
  ('all',        'ALL',        '전체 작업',                       0),
  ('webtoon',    'WEBTOON',    '연재·단편 웹툰',                  1),
  ('product',    'PRODUCT',    '서비스/도구 제품',                2),
  ('service',    'SERVICE',    '클라이언트 워크',                 3),
  ('experiment', 'EXPERIMENT', '실험·프로토타입',                 4);

-- 3) 프로젝트 (6건) — 카테고리 슬러그로 매핑
with cat as (select id, slug from public.categories)
insert into public.projects
  (title, subtitle, description, category_id, year, client, role, tech,
   thumbnail_url, gallery, link_label, link_url, is_featured, is_visible, sort_order)
select t.title, t.subtitle, t.description, cat.id, t.year, t.client, t.role, t.tech,
       t.thumbnail_url, t.gallery::jsonb, t.link_label, t.link_url, t.is_featured, true, t.ord
from cat,
  (values
    ('루갈',
     'Action Webtoon · Serialized',
     E'KakaoPage·네이버 시리즈에 연재된 액션 웹툰. OCN 드라마와 넷플릭스 영상화로 이어진 대표작.\n\n주인공 강기범의 복수극을 중심으로, 인공 신체 기술과 어둠의 조직이 충돌하는 도시 누아르.',
     'webtoon', '2018–2021', 'KakaoPage · Netflix', 'Story · Art', 'Clip Studio · Photoshop',
     'https://images.unsplash.com/photo-1618329027137-ad0aa69f93df?w=1200&q=80',
     '[{"url":"https://images.unsplash.com/photo-1531259683007-016a7b628fc3?w=1400","caption":"커버 비주얼"},{"url":"https://images.unsplash.com/photo-1635805737707-575885ab0820?w=1400","caption":"드라마 키비주얼"}]',
     '작품 보기', 'https://page.kakao.com', true, 1),

    ('만트라 코파일럿',
     'AI Writing Assistant',
     E'웹툰·웹소설 작가를 위한 AI 창작 어시스턴트. 이야기 컨텍스트를 세션 너머로 기억하고, 톤·세계관을 학습합니다.\n\nClaude API와 Supabase 기반의 멀티 프로젝트 워크스페이스.',
     'product', '2025', 'Mantra Studio', 'Product · Development', 'Cloudflare Pages · Supabase · Claude API',
     'https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=1200&q=80',
     '[{"url":"https://images.unsplash.com/photo-1559028012-481c04fa702d?w=1400","caption":"대시보드"}]',
     'Visit', 'https://copilot.mantrastudio.kr', false, 2),

    ('운명의 거울',
     'Fortune Mini App',
     E'토스 플랫폼 위에서 동작하는 사주 기반 운세 미니앱. AI 이미지 생성과 결제를 한 화면에 통합했습니다.\n\n출시 6주 만에 누적 사용자 12만 돌파.',
     'product', '2025', 'Toss · 앱인토스', 'Product · Development', 'Cloudflare Functions · Gemini · Toss Pay',
     'https://images.unsplash.com/photo-1502136969935-8d8eef54d77b?w=1200&q=80',
     '[]', 'Visit', 'https://toss.im', false, 3),

    ('귀신들린 그래플러',
     'Upcoming Webtoon',
     E'피코마에서 런칭 예정인 신작 웹툰. 70컷/화 포맷에 호러·격투·코미디를 혼합한 장르 실험작.\n\n2025년 하반기 일본 동시 연재 시작.',
     'webtoon', '2025–', 'Piccoma', 'Story · Art', 'Clip Studio',
     'https://images.unsplash.com/photo-1509248961158-e54f6934749c?w=1200&q=80',
     '[{"url":"https://images.unsplash.com/photo-1544380370-c3c9bce3837b?w=1400","caption":"캐릭터 라인업"}]',
     'Preview', 'https://piccoma.com', true, 4),

    ('만트라 아트',
     'Art Psychology Analysis',
     E'그림 심리 분석 웹 서비스. 한·영·일·중 4개 언어 지원.\n\nClaude의 비전 모델로 사용자가 그린 그림의 색채·구도·필압을 해석합니다.',
     'service', '2025', 'Mantra Studio', 'Product', 'Cloudflare · Claude API',
     'https://images.unsplash.com/photo-1513364776144-60967b0f800f?w=1200&q=80',
     '[]', 'Visit', 'https://art.mantrastudio.kr', false, 5),

    ('캐릭터 아트 스튜디오',
     'Class Tool',
     E'수업 현장용 캐릭터 생성 파이프라인. Claude 분석 → Gemini 생성 구조로 학생들의 묘사 능력을 돕습니다.\n\n전국 30여 개 미술학원 도입.',
     'service', '2025', 'Kkumiigong', 'Tool Design', 'Cloudflare · Gemini',
     'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=1200&q=80',
     '[]', 'Visit', '#', false, 6)
  ) as t(title, subtitle, description, cat_slug, year, client, role, tech,
         thumbnail_url, gallery, link_label, link_url, is_featured, ord)
where cat.slug = t.cat_slug;

-- 4) 서비스 (4건)
insert into public.services (icon, title, description, sort_order, is_visible) values
  ('W', 'Webtoon',
   '연재 단위의 장편부터 단편 광고물까지, 완결된 이야기를 책임지고 만듭니다.', 1, true),
  ('A', 'AI Tool Dev',
   '창작자를 위한 작은 AI 도구를 설계·개발합니다. 아이디어를 쓸 수 있는 제품으로.', 2, true),
  ('B', 'Brand',
   '작은 브랜드를 위한 아이덴티티, 카피, 비주얼 디렉션.', 3, true),
  ('E', 'Education',
   '웹툰·디지털 드로잉·AI 창작 관련 워크숍과 강의를 제공합니다.', 4, true);

-- 5) 타임라인 (4건)
insert into public.timeline_entries (year, title, description, sort_order, is_visible) values
  ('2018', '웹툰 《루갈》 연재 시작',
   'KakaoPage 액션 장르 연재, 이후 OCN 드라마·넷플릭스 영화 판권 계약.', 1, true),
  ('2023', '만트라 스튜디오 설립',
   '전주를 기반으로 1인 창작 스튜디오 출범. 이야기 + 도구의 결합을 시도.', 2, true),
  ('2024', 'AI 창작 도구 실험 시작',
   '만트라 코파일럿 초기 프로토타입 개발, 작가 베타 그룹 운영.', 3, true),
  ('2025', '제품군 확장',
   '운명의 거울, 만트라 아트 등 퍼블릭 제품 런칭. 누적 사용자 30만 돌파.', 4, true);

commit;
