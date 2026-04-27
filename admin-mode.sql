-- =====================================================================
-- 만트라 스튜디오 — 관리자 모드 (비밀번호 기반 인라인 편집) RPC
-- =====================================================================
-- 전제: inquiries-schema.sql 을 먼저 실행해서 app_secrets / _check_admin_pw 가 있어야 함
-- (없다면 먼저 inquiries-schema.sql 을 돌리세요. 기본 비밀번호: mantra2025)
--
-- 모든 함수는 SECURITY DEFINER + admin_pw 체크 → RLS 우회하여 공개 anon 키로도
-- 비밀번호만 맞으면 콘텐츠 편집 가능. 잘못된 비밀번호는 즉시 예외.
-- =====================================================================

-- ─── 0) 비밀번호만 검증 (admin 모드 진입 시) ───────────────────────────
create or replace function admin_check(p_admin_pw text) returns boolean
language sql security definer set search_path = public, extensions
as $$
  select exists (
    select 1 from app_secrets
    where key = 'admin_pw' and value_hash = crypt(p_admin_pw, value_hash)
  );
$$;
grant execute on function admin_check(text) to anon, authenticated;

-- ─── 1) 사이트 전역 설정 저장 ───────────────────────────────────────
create or replace function admin_save_settings(p_admin_pw text, p_data jsonb)
returns void
language plpgsql security definer set search_path = public, extensions
as $$
begin
  if not admin_check(p_admin_pw) then raise exception '관리자 비밀번호 오류'; end if;
  update studio_settings set
    studio_name        = coalesce(p_data->>'studio_name', studio_name),
    studio_tagline     = coalesce(p_data->>'studio_tagline', studio_tagline),
    studio_description = coalesce(p_data->>'studio_description', studio_description),
    hero_headline      = coalesce(p_data->>'hero_headline', hero_headline),
    hero_subline       = coalesce(p_data->>'hero_subline', hero_subline),
    hero_image_url     = coalesce(p_data->>'hero_image_url', hero_image_url),
    about_body         = coalesce(p_data->>'about_body', about_body),
    about_image_url    = coalesce(p_data->>'about_image_url', about_image_url),
    contact_email      = coalesce(p_data->>'contact_email', contact_email),
    contact_location   = coalesce(p_data->>'contact_location', contact_location),
    social_instagram   = coalesce(p_data->>'social_instagram', social_instagram),
    social_youtube     = coalesce(p_data->>'social_youtube', social_youtube),
    social_twitter     = coalesce(p_data->>'social_twitter', social_twitter),
    social_github      = coalesce(p_data->>'social_github', social_github),
    footer_copyright   = coalesce(p_data->>'footer_copyright', footer_copyright),
    seo_description    = coalesce(p_data->>'seo_description', seo_description),
    theme_bg           = coalesce(p_data->>'theme_bg', theme_bg),
    theme_fg           = coalesce(p_data->>'theme_fg', theme_fg),
    theme_accent       = coalesce(p_data->>'theme_accent', theme_accent),
    logo_url           = coalesce(p_data->>'logo_url', logo_url)
  where id = 1;
end;
$$;
grant execute on function admin_save_settings(text, jsonb) to anon, authenticated;

-- ─── 2) 프로젝트 저장 (id=null이면 신규, 있으면 update) ───────────────
create or replace function admin_save_project(p_admin_pw text, p_id uuid, p_data jsonb)
returns uuid
language plpgsql security definer set search_path = public, extensions
as $$
declare out_id uuid;
begin
  if not admin_check(p_admin_pw) then raise exception '관리자 비밀번호 오류'; end if;
  if p_id is null then
    insert into projects (
      title, subtitle, description, category_id, year, client, role, tech,
      thumbnail_url, link_label, link_url, is_visible, is_featured, gallery, sort_order
    ) values (
      p_data->>'title',
      p_data->>'subtitle',
      p_data->>'description',
      nullif(p_data->>'category_id','')::uuid,
      p_data->>'year',
      p_data->>'client',
      p_data->>'role',
      p_data->>'tech',
      p_data->>'thumbnail_url',
      p_data->>'link_label',
      p_data->>'link_url',
      coalesce((p_data->>'is_visible')::boolean, true),
      coalesce((p_data->>'is_featured')::boolean, false),
      coalesce(p_data->'gallery', '[]'::jsonb),
      coalesce((p_data->>'sort_order')::int, (select coalesce(max(sort_order),0)+1 from projects))
    ) returning id into out_id;
  else
    update projects set
      title         = coalesce(p_data->>'title', title),
      subtitle      = coalesce(p_data->>'subtitle', subtitle),
      description   = coalesce(p_data->>'description', description),
      category_id   = coalesce(nullif(p_data->>'category_id','')::uuid, category_id),
      year          = coalesce(p_data->>'year', year),
      client        = coalesce(p_data->>'client', client),
      role          = coalesce(p_data->>'role', role),
      tech          = coalesce(p_data->>'tech', tech),
      thumbnail_url = coalesce(p_data->>'thumbnail_url', thumbnail_url),
      link_label    = coalesce(p_data->>'link_label', link_label),
      link_url      = coalesce(p_data->>'link_url', link_url),
      is_visible    = coalesce((p_data->>'is_visible')::boolean, is_visible),
      is_featured   = coalesce((p_data->>'is_featured')::boolean, is_featured),
      gallery       = coalesce(p_data->'gallery', gallery)
    where id = p_id
    returning id into out_id;
  end if;
  return out_id;
end;
$$;
grant execute on function admin_save_project(text, uuid, jsonb) to anon, authenticated;

create or replace function admin_delete_project(p_admin_pw text, p_id uuid) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not admin_check(p_admin_pw) then raise exception '관리자 비밀번호 오류'; end if;
  delete from projects where id = p_id;
  return true;
end; $$;
grant execute on function admin_delete_project(text, uuid) to anon, authenticated;

-- ─── 3) 서비스 카드 저장/삭제 ──────────────────────────────────────
create or replace function admin_save_service(p_admin_pw text, p_id uuid, p_data jsonb)
returns uuid
language plpgsql security definer set search_path = public, extensions
as $$
declare out_id uuid;
begin
  if not admin_check(p_admin_pw) then raise exception '관리자 비밀번호 오류'; end if;
  if p_id is null then
    insert into services (title, description, icon, is_visible, sort_order)
    values (
      p_data->>'title', p_data->>'description', p_data->>'icon',
      coalesce((p_data->>'is_visible')::boolean, true),
      coalesce((p_data->>'sort_order')::int, (select coalesce(max(sort_order),0)+1 from services))
    ) returning id into out_id;
  else
    update services set
      title       = coalesce(p_data->>'title', title),
      description = coalesce(p_data->>'description', description),
      icon        = coalesce(p_data->>'icon', icon),
      is_visible  = coalesce((p_data->>'is_visible')::boolean, is_visible)
    where id = p_id
    returning id into out_id;
  end if;
  return out_id;
end;
$$;
grant execute on function admin_save_service(text, uuid, jsonb) to anon, authenticated;

create or replace function admin_delete_service(p_admin_pw text, p_id uuid) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not admin_check(p_admin_pw) then raise exception '관리자 비밀번호 오류'; end if;
  delete from services where id = p_id;
  return true;
end; $$;
grant execute on function admin_delete_service(text, uuid) to anon, authenticated;

-- ─── 4) 타임라인 항목 저장/삭제 ─────────────────────────────────────
create or replace function admin_save_timeline(p_admin_pw text, p_id uuid, p_data jsonb)
returns uuid
language plpgsql security definer set search_path = public, extensions
as $$
declare out_id uuid;
begin
  if not admin_check(p_admin_pw) then raise exception '관리자 비밀번호 오류'; end if;
  if p_id is null then
    insert into timeline_entries (year, title, description, is_visible, sort_order)
    values (
      p_data->>'year', p_data->>'title', p_data->>'description',
      coalesce((p_data->>'is_visible')::boolean, true),
      coalesce((p_data->>'sort_order')::int, (select coalesce(max(sort_order),0)+1 from timeline_entries))
    ) returning id into out_id;
  else
    update timeline_entries set
      year        = coalesce(p_data->>'year', year),
      title       = coalesce(p_data->>'title', title),
      description = coalesce(p_data->>'description', description),
      is_visible  = coalesce((p_data->>'is_visible')::boolean, is_visible)
    where id = p_id
    returning id into out_id;
  end if;
  return out_id;
end;
$$;
grant execute on function admin_save_timeline(text, uuid, jsonb) to anon, authenticated;

create or replace function admin_delete_timeline(p_admin_pw text, p_id uuid) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not admin_check(p_admin_pw) then raise exception '관리자 비밀번호 오류'; end if;
  delete from timeline_entries where id = p_id;
  return true;
end; $$;
grant execute on function admin_delete_timeline(text, uuid) to anon, authenticated;

-- ─── 5) 카테고리 저장/삭제 (선택: 인라인에서 카테고리도 만들고 싶을 때) ──
create or replace function admin_save_category(p_admin_pw text, p_id uuid, p_data jsonb)
returns uuid
language plpgsql security definer set search_path = public, extensions
as $$
declare out_id uuid;
begin
  if not admin_check(p_admin_pw) then raise exception '관리자 비밀번호 오류'; end if;
  if p_id is null then
    insert into categories (slug, label, description, sort_order)
    values (
      p_data->>'slug', p_data->>'label', p_data->>'description',
      coalesce((p_data->>'sort_order')::int, (select coalesce(max(sort_order),0)+1 from categories))
    ) returning id into out_id;
  else
    update categories set
      slug        = coalesce(p_data->>'slug', slug),
      label       = coalesce(p_data->>'label', label),
      description = coalesce(p_data->>'description', description)
    where id = p_id
    returning id into out_id;
  end if;
  return out_id;
end;
$$;
grant execute on function admin_save_category(text, uuid, jsonb) to anon, authenticated;

create or replace function admin_delete_category(p_admin_pw text, p_id uuid) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not admin_check(p_admin_pw) then raise exception '관리자 비밀번호 오류'; end if;
  delete from categories where id = p_id;
  return true;
end; $$;
grant execute on function admin_delete_category(text, uuid) to anon, authenticated;
