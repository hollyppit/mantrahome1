# 만트라 스튜디오 소개 사이트

- `public/` : 화면 (index.html, logo.png)
- `functions/api/contact.js` : 문의 메일 발송 (Cloudflare Pages Functions + Resend)

## 설정과 배포 (PowerShell, 이 폴더에서 실행)

1. [resend.com](https://resend.com)에 **문의를 받을 메일 주소로** 가입하고 API Key 발급
2. Cloudflare 로그인

```powershell
npx wrangler login
```

3. 프로젝트 생성 (최초 1회)

```powershell
npx wrangler pages project create mantra-studio --production-branch main
```

4. API 키 등록 (실행 후 키 붙여넣기)

```powershell
npx wrangler pages secret put RESEND_API_KEY --project-name mantra-studio
```

5. 받을 메일 주소 등록 (실행 후 주소 입력)

```powershell
npx wrangler pages secret put CONTACT_TO --project-name mantra-studio
```

6. 배포

```powershell
npx wrangler pages deploy public --project-name mantra-studio --branch main
```

Cloudflare 대시보드에서 파일을 끌어다 놓는 방식은 `functions/`가 빠져 문의 전송이 동작하지 않습니다.

## 보내는 주소

도메인 인증 전에는 `onboarding@resend.dev`에서 발송되며, Resend 가입 메일 주소로만 받을 수 있습니다.
Resend에서 도메인을 인증하면 `CONTACT_FROM` 값을 `만트라 스튜디오 <contact@내도메인>` 형태로 등록하세요.
