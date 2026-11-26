// Cloudflare Pages Function: POST /api/contact → Resend 로 문의 메일 발송
// 환경변수: RESEND_API_KEY, CONTACT_TO (받을 메일), CONTACT_FROM (선택)

const json = (body, status = 200) => Response.json(body, { status });

export async function onRequestPost({ request, env }) {
  let data;
  try {
    data = await request.json();
  } catch {
    return json({ error: '잘못된 요청입니다.' }, 400);
  }

  const field = key => String(data?.[key] ?? '').trim();

  // 스팸봇이 숨은 칸을 채우면 성공한 척하고 보내지 않음
  if (field('website')) return json({ ok: true });

  const name = field('name').replace(/[\r\n]+/g, ' ');
  const email = field('email');
  const phone = field('phone');
  const message = field('message');

  if (!name || !email || !message) return json({ error: '이름, 이메일, 문의 내용을 입력해 주세요.' }, 400);
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return json({ error: '이메일 형식을 확인해 주세요.' }, 400);
  if (name.length > 60 || email.length > 120 || phone.length > 30 || message.length > 3000) {
    return json({ error: '입력한 내용이 너무 깁니다.' }, 400);
  }
  if (!data.agree) return json({ error: '개인정보 수집·이용에 동의해 주세요.' }, 400);

  const failed = json({ error: '전송에 실패했습니다. 잠시 후 다시 시도해 주세요.' }, 502);

  if (!env.RESEND_API_KEY || !env.CONTACT_TO) {
    console.error('RESEND_API_KEY 또는 CONTACT_TO 환경변수가 없습니다.');
    return failed;
  }

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: env.CONTACT_FROM || 'Mantra Studio <onboarding@resend.dev>',
        // 쉼표로 여러 주소 지정 가능
        to: env.CONTACT_TO.split(',').map(s => s.trim()).filter(Boolean),
        reply_to: email,
        subject: `[홈페이지 문의] ${name}`,
        text: `이름: ${name}\n이메일: ${email}\n연락처: ${phone || '-'}\n\n${message}`,
      }),
    });
    if (!res.ok) {
      console.error('Resend 오류', res.status, await res.text());
      return failed;
    }
  } catch (err) {
    console.error('Resend 연결 실패', err);
    return failed;
  }

  return json({ ok: true });
}
