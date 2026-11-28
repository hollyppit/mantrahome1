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

`/admin.html` 에서 관리자 비밀번호로 로그인하면 원하는 이메일로 이미지·영상·ZIP·PDF 등을 첨부해 보낼 수 있습니다.

- 화면: `public/admin.html` / 발송: `functions/api/admin/send.js` / 비밀번호 검사: `functions/api/admin/_middleware.js`
- 한 번에 최대 약 28MB (Resend 한 통 40MB 제한, 첨부는 base64로 커짐)
- 받는 사람이 답장하면 `CONTACT_TO`의 첫 번째 주소로 갑니다.
- `.exe` 같은 실행 파일은 Resend가 거부합니다.

관리자 비밀번호 등록 (최초 1회, 실행 후 비밀번호 입력):

```powershell
npx.cmd wrangler pages secret put ADMIN_PASSWORD --project-name mantrahome1
```

등록 후 GitHub(main)에 push 해서 다시 배포해야 적용됩니다. (mantrahome1 은 GitHub 연결 프로젝트라 push 하면 자동 배포)

## 보내는 주소

도메인 인증 전에는 `onboarding@resend.dev`에서 발송되며, Resend 가입 메일 주소로만 받을 수 있습니다.
Resend에서 도메인을 인증하면 `CONTACT_FROM` 값을 `만트라 스튜디오 <contact@내도메인>` 형태로 등록하세요.
