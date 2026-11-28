# 만트라 스튜디오 소개 사이트

- `public/` : 화면 (index.html, logo.png)
- `functions/api/contact.js` : 문의 메일 발송 (Cloudflare Pages Functions + Resend)

## 설정과 배포 (PowerShell, 이 폴더에서 실행)

1. [resend.com](https://resend.com)에 **문의를 받을 메일 주소로** 가입하고 API Key 발급
2. Cloudflare 로그인

```powershell
npx.cmd wrangler login
```

3. 프로젝트 생성 (최초 1회)

```powershell
npx.cmd wrangler pages project create mantrahome1 --production-branch main
```

4. API 키 등록 (실행 후 키 붙여넣기)

```powershell
npx.cmd wrangler pages secret put RESEND_API_KEY --project-name mantrahome1
```

5. 받을 메일 주소 등록 (실행 후 주소 입력)

```powershell
npx.cmd wrangler pages secret put CONTACT_TO --project-name mantrahome1
```

6. 배포

```powershell
npx.cmd wrangler pages deploy public --project-name mantrahome1 --branch main
```

Cloudflare 대시보드에서 파일을 끌어다 놓는 방식은 `functions/`가 빠져 문의 전송이 동작하지 않습니다.

## 관리자 파일 보내기

`https://mantrastudio.cc/admin` 에서 관리자 비밀번호로 로그인하면 이미지·영상·ZIP·PDF 등을 보낼 수 있습니다.

| 보내는 방법 | 방식 | 한도 |
|---|---|---|
| 이메일 · 파일 첨부 | 메일에 직접 첨부 (Resend) | 한 번에 약 28MB |
| 이메일 · 다운로드 링크 | Supabase에 올리고 링크 발송 | 파일당 50MB, 20개 |
| 알림톡 / 네이버 톡톡 | Supabase에 올리고 링크 발송 (Solapi) | 파일당 50MB, 20개 |

- 링크는 `https://mantrastudio.cc/f/<코드>` 형태이고 **14일** 뒤 막힙니다. 지난 파일은 다음에 파일을 올릴 때 자동으로 지워집니다.
- 파일은 Supabase `mantrahome1` 프로젝트의 비공개 버킷 `shared-files`, 목록은 `file_shares` 테이블에 있습니다.
- 받는 사람이 이메일에 답장하면 `CONTACT_TO`의 첫 번째 주소로 갑니다. `.exe` 같은 실행 파일은 Resend가 거부합니다.
- 코드: 화면 `public/admin.html`, 첨부 발송 `functions/api/admin/send.js`, 링크 발송 `functions/api/admin/share/*`, 받는 페이지 `functions/f/[id].js`, 공통 `lib/`

### 필요한 설정 (Cloudflare 비밀값)

각 줄을 실행하고 값을 붙여넣은 뒤, 다시 배포해야 적용됩니다.

| 이름 | 값 | 어디서 |
|---|---|---|
| `ADMIN_PASSWORD` | 관리자 비밀번호 | 직접 정하기 |
| `SUPABASE_SERVICE_ROLE_KEY` | service_role 키 (또는 `sb_secret_...` 키) | Supabase → mantrahome1 → Project Settings → API Keys |
| `SOLAPI_API_KEY`, `SOLAPI_API_SECRET` | API Key / API Secret | Solapi 콘솔 → 개발/연동 → API Key 관리 |
| `SOLAPI_SENDER` | 등록된 발신번호 (예: 07045196416) | Solapi 콘솔 → 발신번호 관리 |
| `SOLAPI_KAKAO_PFID` | 카카오 채널 pfId (`KA01PF...`) | Solapi 콘솔 → 카카오 채널 |
| `SOLAPI_KAKAO_TEMPLATE_ID` | 승인된 알림톡 템플릿 ID (`KA01TP...`) | Solapi 콘솔 → 알림톡 템플릿 |
| `SOLAPI_NAVER_TALK_ID` | 네이버 톡톡 계정 ID | Solapi 콘솔 → 네이버 톡톡 |
| `SOLAPI_NAVER_TEMPLATE_ID` | 승인된 네이버 톡톡 템플릿 ID | Solapi 콘솔 → 네이버 톡톡 템플릿 |

```powershell
npx.cmd wrangler pages secret put SUPABASE_SERVICE_ROLE_KEY --project-name mantrahome1
```

(다른 값도 이름만 바꿔서 같은 방법으로 등록)

### 알림톡 · 네이버 톡톡 템플릿 문구

두 곳 모두 아래 문구로 템플릿을 등록해 승인을 받으세요. **변수 이름(`#{이름}` `#{파일}` `#{만료일}` `#{코드}`)은 바꾸면 안 됩니다.** 코드가 이 네 변수를 채워 보냅니다.

```
[만트라 스튜디오] 파일 전달 안내

#{이름}님, 요청하신 파일을 보내드립니다.

■ 파일: #{파일}
■ 받을 수 있는 기간: #{만료일}까지

아래 링크에서 파일을 받으실 수 있습니다.
https://mantrastudio.cc/f/#{코드}
```

- 템플릿 유형: 기본형, 정보성 메시지
- 버튼은 넣지 않습니다. (링크는 본문에 있음)
- 채워지는 값 예시: `#{이름}` 홍길동(비우면 "고객") · `#{파일}` 작업물.mp4 외 2개 · `#{만료일}` 2026년 12월 12일 · `#{코드}` HSZUVjPRmyBm
- 알림톡은 SMS 대체 발송을 끈 상태로 보냅니다. (실패 시 문자로 가지 않음)

관리자 비밀번호 등록 (최초 1회, 실행 후 비밀번호 입력):

```powershell
npx.cmd wrangler pages secret put ADMIN_PASSWORD --project-name mantrahome1
```

등록 후 GitHub(main)에 push 해서 다시 배포해야 적용됩니다. (mantrahome1 은 GitHub 연결 프로젝트라 push 하면 자동 배포)

## 보내는 주소

도메인 인증 전에는 `onboarding@resend.dev`에서 발송되며, Resend 가입 메일 주소로만 받을 수 있습니다.
Resend에서 도메인을 인증하면 `CONTACT_FROM` 값을 `만트라 스튜디오 <contact@내도메인>` 형태로 등록하세요.
