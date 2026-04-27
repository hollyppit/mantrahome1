-- =====================================================================
-- 만트라 스튜디오 — 문의 게시판 (비밀글) 스키마
-- 사용법: Supabase 대시보드 → SQL Editor → New query → 전체 붙여넣고 Run
-- 이 스크립트는 여러 번 실행해도 안전합니다 (idempotent).
-- =====================================================================

create extension if not exists pgcrypto;

-- ─────────────────────────────────────────────────────────────────────
-- 1) 관리자 비밀번호 보관용 (bcrypt 해시)
-- ─────────────────────────────────────────────────────────────────────
create table if not exists app_secrets (
  key        text primary key,
  value_hash text not null,
  updated_at timestamptz not null default now()
);
alter table app_secrets enable row level security;
-- 정책 없음 → anon/authenticated 모두 직접 접근 불가

-- 초기 admin 비밀번호 'mantra2025' 등록 (이미 있으면 skip)
insert into app_secrets (key, value_hash)
values ('admin_pw', crypt('mantra2025', gen_salt('bf')))
on conflict (key) do nothing;

-- ─────────────────────────────────────────────────────────────────────
-- 2) 문의 테이블 (비밀글)
-- ─────────────────────────────────────────────────────────────────────
create table if not exists inquiries (
  id           bigserial primary key,
  title        text not null,
  body         text not null,
  contact      text,
  edit_pw_hash text not null,
  is_read      boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
alter table inquiries enable row level security;
-- 정책 없음 → 직접 접근 불가, RPC를 통해서만 가능

create index if not exists inquiries_created_at_idx on inquiries(created_at desc);

-- ─────────────────────────────────────────────────────────────────────
-- 헬퍼: 관리자 비밀번호 검증 (내부용, anon에 grant하지 않음)
-- ─────────────────────────────────────────────────────────────────────
create or replace function _check_admin_pw(p_pw text) returns boolean
language sql security definer set search_path = public, extensions
as $$
  select exists (
    select 1 from app_secrets
    where key = 'admin_pw' and value_hash = crypt(p_pw, value_hash)
  );
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 3) [익명] 문의 작성
--    return: 새로 만들어진 문의 ID (bigint)
-- ─────────────────────────────────────────────────────────────────────
create or replace function submit_inquiry(
  p_title text, p_body text, p_contact text, p_edit_pw text
) returns bigint
language plpgsql security definer set search_path = public, extensions
as $$
declare
  new_id bigint;
begin
  if p_title is null or length(trim(p_title)) = 0 then
    raise exception '제목을 입력해 주세요.';
  end if;
  if p_body is null or length(trim(p_body)) = 0 then
    raise exception '내용을 입력해 주세요.';
  end if;
  if p_edit_pw is null or length(p_edit_pw) < 4 then
    raise exception '수정용 비밀번호는 4자 이상이어야 합니다.';
  end if;
  insert into inquiries (title, body, contact, edit_pw_hash)
  values (trim(p_title), p_body, nullif(trim(coalesce(p_contact,'')), ''), crypt(p_edit_pw, gen_salt('bf')))
  returning id into new_id;
  return new_id;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 4) [본인] 문의 조회 (id + 비밀번호 일치 시 1행 반환)
-- ─────────────────────────────────────────────────────────────────────
create or replace function verify_inquiry(p_id bigint, p_edit_pw text)
returns table (
  id bigint, title text, body text, contact text,
  is_read boolean, created_at timestamptz, updated_at timestamptz
)
language plpgsql security definer set search_path = public, extensions
as $$
begin
  return query
    select i.id, i.title, i.body, i.contact, i.is_read, i.created_at, i.updated_at
    from inquiries i
    where i.id = p_id
      and i.edit_pw_hash = crypt(p_edit_pw, i.edit_pw_hash);
end;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 5) [본인] 문의 수정
-- ─────────────────────────────────────────────────────────────────────
create or replace function update_inquiry_by_user(
  p_id bigint, p_edit_pw text,
  p_title text, p_body text, p_contact text
) returns boolean
language plpgsql security definer set search_path = public, extensions
as $$
declare
  affected int;
begin
  if p_title is null or length(trim(p_title)) = 0 then
    raise exception '제목을 입력해 주세요.';
  end if;
  if p_body is null or length(trim(p_body)) = 0 then
    raise exception '내용을 입력해 주세요.';
  end if;
  update inquiries
     set title      = trim(p_title),
         body       = p_body,
         contact    = nullif(trim(coalesce(p_contact,'')), ''),
         updated_at = now()
   where id = p_id
     and edit_pw_hash = crypt(p_edit_pw, edit_pw_hash);
  get diagnostics affected = row_count;
  return affected > 0;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 6) [본인] 문의 삭제
-- ─────────────────────────────────────────────────────────────────────
create or replace function delete_inquiry_by_user(p_id bigint, p_edit_pw text)
returns boolean
language plpgsql security definer set search_path = public, extensions
as $$
declare
  affected int;
begin
  delete from inquiries
   where id = p_id
     and edit_pw_hash = crypt(p_edit_pw, edit_pw_hash);
  get diagnostics affected = row_count;
  return affected > 0;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 7) [관리자] 전체 목록
-- ─────────────────────────────────────────────────────────────────────
create or replace function list_inquiries(p_admin_pw text)
returns table (
  id bigint, title text, body text, contact text,
  is_read boolean, created_at timestamptz, updated_at timestamptz
)
language plpgsql security definer set search_path = public, extensions
as $$
begin
  if not _check_admin_pw(p_admin_pw) then
    raise exception '관리자 비밀번호가 올바르지 않습니다.';
  end if;
  return query
    select i.id, i.title, i.body, i.contact, i.is_read, i.created_at, i.updated_at
    from inquiries i
    order by i.created_at desc;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 8) [관리자] 읽음 처리
-- ─────────────────────────────────────────────────────────────────────
create or replace function mark_inquiry_read(p_admin_pw text, p_id bigint, p_is_read boolean default true)
returns boolean
language plpgsql security definer set search_path = public, extensions
as $$
declare
  affected int;
begin
  if not _check_admin_pw(p_admin_pw) then
    raise exception '관리자 비밀번호가 올바르지 않습니다.';
  end if;
  update inquiries set is_read = p_is_read where id = p_id;
  get diagnostics affected = row_count;
  return affected > 0;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 9) [관리자] 삭제
-- ─────────────────────────────────────────────────────────────────────
create or replace function delete_inquiry(p_admin_pw text, p_id bigint)
returns boolean
language plpgsql security definer set search_path = public, extensions
as $$
declare
  affected int;
begin
  if not _check_admin_pw(p_admin_pw) then
    raise exception '관리자 비밀번호가 올바르지 않습니다.';
  end if;
  delete from inquiries where id = p_id;
  get diagnostics affected = row_count;
  return affected > 0;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- 10) [관리자] 비밀번호 변경
-- ─────────────────────────────────────────────────────────────────────
create or replace function change_admin_pw(p_old_pw text, p_new_pw text)
returns boolean
language plpgsql security definer set search_path = public, extensions
as $$
begin
  if not _check_admin_pw(p_old_pw) then
    raise exception '현재 관리자 비밀번호가 올바르지 않습니다.';
  end if;
  if p_new_pw is null or length(p_new_pw) < 6 then
    raise exception '새 비밀번호는 6자 이상이어야 합니다.';
  end if;
  update app_secrets
     set value_hash = crypt(p_new_pw, gen_salt('bf')),
         updated_at = now()
   where key = 'admin_pw';
  return true;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────
-- RPC 실행 권한 (anon/authenticated)
-- ─────────────────────────────────────────────────────────────────────
grant execute on function submit_inquiry(text, text, text, text)            to anon, authenticated;
grant execute on function verify_inquiry(bigint, text)                       to anon, authenticated;
grant execute on function update_inquiry_by_user(bigint, text, text, text, text) to anon, authenticated;
grant execute on function delete_inquiry_by_user(bigint, text)               to anon, authenticated;
grant execute on function list_inquiries(text)                               to anon, authenticated;
grant execute on function mark_inquiry_read(text, bigint, boolean)           to anon, authenticated;
grant execute on function delete_inquiry(text, bigint)                       to anon, authenticated;
grant execute on function change_admin_pw(text, text)                        to anon, authenticated;
