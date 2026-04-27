# 만트라 스튜디오 · 포트폴리오 사이트

전주 기반 1인 창작 스튜디오 포트폴리오. 쇼핑몰 스켈레톤의 헤더/드로어/섹션/푸터 레이아웃을 유지하면서, **포트폴리오 전용**으로 재설계된 템플릿입니다.

## 📁 파일 구성

```
mantra-site/
├── index.html              # 공개 포트폴리오 사이트
├── admin.html              # 관리자 (로그인 필요)
├── supabase-schema.sql     # Supabase 테이블 생성 SQL (필수)
├── sample-data.sql         # 데모 콘텐츠 시드 (선택)
├── inquiries-schema.sql    # 문의 게시판(비밀글) 스키마 (선택)
├── admin-mode.sql          # 관리자 모드 — 비밀번호로 인라인 편집 RPC (선택)
├── i18n-migration.sql      # 한/영 다국어 컬럼 추가 (선택)
└── README.md               # 이 문서
```

## 🎨 디자인 컨셉

- **톤**: 모노크롬 에디토리얼 + 스튜디오 매거진
- **폰트**: Instrument Serif(이탤릭 헤드라인) + Noto Sans KR(본문) + JetBrains Mono(레이블)
- **차별점**: 볼드 사이트가 "브랜드 타이포" 중심이었다면, 만트라는 **프로젝트 비정형 그리드 + 상세 모달**이 중심
- **상징색**: `#d94b2b` (테라코타)

## 🧩 공개 사이트의 섹션들

1. **Hero** — 이탤릭 세리프 헤드라인 + 사이드 비주얼 + 메타정보
2. **Ticker** — 스크롤 배너 (서비스 키워드)
3. **About** — 좌 이미지 + 우 본문 (2컬럼)
4. **Services** — 4칸 그리드 카드 (무엇을 하는가)
5. **Works** — 카테고리 필터 + **비정형 그리드** + 클릭 시 **상세 모달**
6. **Journey** — 연혁 타임라인
7. **Contact CTA** — 풀 화면 다크 섹션
8. **Footer** — 4컬럼

## 🚀 초기 설정 (최초 1회)

### 1. Supabase 프로젝트
1. [supabase.com](https://supabase.com) → New project
2. **Settings → API**에서 `Project URL`과 `anon public` key 복사

### 2. 테이블 생성
- Supabase Dashboard → **SQL Editor** → `supabase-schema.sql` 전체 붙여넣고 Run
- 테이블 5개가 생성됩니다: `studio_settings`, `categories`, `projects`, `services`, `timeline_entries`
- (선택) `sample-data.sql`을 추가로 실행하면 카테고리 5개·프로젝트 6건·서비스 4건·타임라인 4건이 즉시 채워집니다.
- (선택) `inquiries-schema.sql`을 실행하면 방문자 문의 게시판(비밀글) + 관리자 RPC가 추가됩니다. 초기 관리자 비밀번호는 `mantra2025` — 첫 로그인 후 즉시 바꾸세요.
- (선택) `admin-mode.sql`을 추가로 실행하면 **index.html에서 직접** 비밀번호로 관리자 모드를 켜고 각 섹션을 인라인 편집할 수 있습니다 (`inquiries-schema.sql` 선행 필요).
- (선택) `i18n-migration.sql`을 실행하면 모든 콘텐츠 테이블에 `*_en` 컬럼이 추가되어 한/영 토글이 가능해집니다.

### 3. 관리자 계정
- **Authentication → Users → Add user**
- 이메일·비밀번호 입력 후 **Auto Confirm User** 체크

### 4. 코드에 키 입력
`index.html`과 `admin.html` 두 파일 모두:
```js
const SUPABASE_URL = 'https://YOUR-PROJECT.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR-ANON-KEY';
```

### 5. 기본 카테고리 생성 (권장)
관리자 로그인 후 **카테고리** 탭에서 슬러그 `all` (라벨 `ALL`) 하나를 먼저 만드세요. 이게 "전체 보기" 필터가 됩니다. 그다음 `webtoon`, `product`, `service` 같은 실제 카테고리를 추가.

### 6. 배포
Cloudflare Pages (기존 만트라 스택과 동일):
- GitHub에 `mantra-site/` 푸시 → Pages 연결 → Build command 비움 → Deploy

## ✍️ 관리자 페이지 구조

| 탭 | 내용 |
|---|---|
| **Dashboard** | 통계 · 빠른 링크 |
| **Site settings** | 로고/히어로/어바웃/연락처/소셜/색상 |
| **Categories** | 포트폴리오 필터 관리 |
| **Projects** | 프로젝트 CRUD + 갤러리 이미지 배열 + featured 플래그 |
| **Services** | "무엇을 하는가" 카드 |
| **Timeline** | 연혁 |
| **문의 게시판** | 방문자 비밀글 문의 확인·읽음 처리·삭제 (별도 비밀번호) |
| **Backup/Restore** | JSON 내보내기/가져오기 |

## 🔑 포트폴리오 특화 기능

### 비정형 그리드 자동 배치
프로젝트 카드는 `nth-child`에 따라 폭이 자동으로 달라져 잡지 레이아웃처럼 보입니다. `is_featured = true` 프로젝트는 더 넓게(6 컬럼).

### 프로젝트 상세 모달
카드 클릭 시 모달이 열리며:
- 커버 이미지
- 카테고리 · 제목 · 부제
- **메타 4종**: YEAR / CLIENT / ROLE / STACK
- 상세 설명
- **갤러리 이미지 배열** (캡션 지원)
- 외부 링크 버튼

### 갤러리 에디터
프로젝트 편집 모달 하단에서 **이미지 URL + 캡션** 쌍을 여러 개 추가/삭제 가능. JSON 배열로 저장됩니다.

## 🔒 보안

- 공개 사이트는 anon key로 읽기만 (RLS로 보호)
- 관리자는 Supabase Auth 로그인 필수
- anon key는 공개해도 안전 / **service role key는 절대 프론트에 넣지 말 것**

## 💡 진우님 스택과의 통합 팁

- 이미지 호스팅: 기존 **Supabase Storage** 버킷 재활용 가능 (Public 읽기 권한 주면 URL 직접 붙여넣기)
- 배포: 기존 Mantra 제품군과 같은 **Cloudflare Pages** 계정에 서브도메인으로 (예: `studio.mantrastudio.com`)
- GitHub Actions 오토핑: 기존에 쓰시던 Supabase 무료 플랜 오토핑 워크플로우에 이 DB도 포함시키면 같이 살아있게 유지됨

## 🔧 관리자 모드 (인라인 편집)

`inquiries-schema.sql` + `admin-mode.sql` 두 파일을 실행하면:

- 공개 사이트(`index.html`) 우상단 **"관리자"** 클릭 → 비밀번호 입력 (기본 `mantra2025`) → 즉시 **관리자 모드 진입**
- 각 섹션 (Hero / About / Services / Works / Journey / Contact) 우상단에 **✎ 버튼** 표시
- ✎ 클릭 → 인라인 모달에서 그 섹션만 편집 → 저장 즉시 화면 갱신
- 서비스/프로젝트/타임라인 섹션 하단에는 **＋ 추가** 버튼으로 신규 항목 생성
- "종료" 버튼 또는 "관리자" 다시 클릭으로 일반 모드 복귀
- 카테고리·갤러리·일괄 백업 등 고급 작업은 admin 바의 **"고급 편집"** 링크 → `admin.html`

> Supabase Auth 계정 없이도 **비밀번호 하나만**으로 콘텐츠 편집 가능. 비밀번호는 sessionStorage에 보관되어 새로고침 후에도 유지되며, 탭 종료 시 자동 만료.

## 💬 문의 게시판 (선택)

`inquiries-schema.sql` 실행 시:

- **방문자**: 상단 유틸의 "문의하기" → 제목·내용·연락처(선택)·**4자 이상 비밀번호** 작성 → 등록 후 **문의 번호 #N** 발급
- **본인 확인/수정/삭제**: "내 문의" → 문의 번호 + 비밀번호 입력
- **관리자**: admin.html → "문의 게시판" 탭 → 별도 관리자 비밀번호로 접근 (기본 `mantra2025`, 즉시 변경 권장)
- 사이드바의 미확인 문의 수가 빨간 배지로 표시됨
- bcrypt 해시 + RPC만 anon 노출 → 직접 SELECT 불가, 보안 안전

## 🌐 한/영 다국어 (선택)

`i18n-migration.sql` 실행 시:

- 사이트 헤더 우측에 **🌐 ENGLISH / 한국어** 토글 표시 (선택은 localStorage 저장)
- 관리자 모든 편집 화면에 **EN 입력 필드**가 함께 표시됨 (비워두면 자동으로 KR 폴백)
- 마이그레이션 미실행 환경에서도 admin은 자동으로 EN 컬럼을 떨어내고 저장 (안전)

## 🚧 확장 아이디어

- **Supabase Storage 업로드 UI** 붙이기 (현재는 URL 직접 입력)
- **Works 개별 페이지**: 모달 대신 `/work/slug` 라우트 (Cloudflare Pages Functions로)
- **뉴스/블로그 섹션**: `posts` 테이블 추가
- **다국어**: 각 텍스트 필드에 `_en`, `_ja` 컬럼 추가 (만트라 아트 방식)
- **Contact 폼**: Cloudflare Functions + 이메일 전송 (Resend API 등)

## 📝 라이선스

자유롭게 수정·사용하세요. 참고한 원본(mantrastudio.clickn.co.kr)은 일반적인 쇼핑몰 스켈레톤만 참고했고, 이 코드는 모두 새로 작성되었습니다.
