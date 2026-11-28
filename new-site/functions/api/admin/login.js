// POST /api/admin/login : 비밀번호 확인만 (검사는 _middleware.js 에서)
export const onRequestPost = () => Response.json({ ok: true });
