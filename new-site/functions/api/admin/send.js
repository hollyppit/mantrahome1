// POST /api/admin/send : 관리자가 첨부파일을 담아 메일 발송 (Resend)
// 환경변수: RESEND_API_KEY, CONTACT_FROM (보내는 주소), CONTACT_TO (답장 받을 주소, 첫 번째 사용)
//
// 요청 본문 = 메일 정보 JSON 한 줄 + "\n" + 첨부 배열 JSON ([{ filename, content(base64) }])
// 첨부는 브라우저에서 base64 로 만들어 오고, 여기서는 해석하지 않고 Resend 로 그대로 흘려보냄.
// (무료 요금제의 CPU 시간 제한 안에서 큰 파일도 보내기 위해)

const json = (body, status = 200) => Response.json(body, { status });
const enc = new TextEncoder();

// Resend 한 통 최대 40MB (base64 포함)
const MAX_BODY = 40 * 1024 * 1024;
const MAX_TO = 10;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export async function onRequestPost({ request, env }) {
  if (!env.RESEND_API_KEY) {
    console.error('RESEND_API_KEY 환경변수가 없습니다.');
    return json({ error: '메일 설정이 되어 있지 않습니다.' }, 503);
  }

  const total = Number(request.headers.get('Content-Length'));
  if (!total || !request.body) return json({ error: '잘못된 요청입니다.' }, 400);
  if (total > MAX_BODY) return json({ error: '첨부파일이 너무 큽니다. 한 번에 약 28MB까지 보낼 수 있습니다.' }, 413);

  // 첫 줄(메일 정보)만 읽기
  const reader = request.body.getReader();
  let head = new Uint8Array(0);
  let nl = -1;
  while (nl < 0) {
    const { value, done } = await reader.read();
    if (done || head.length > 256 * 1024) return json({ error: '잘못된 요청입니다.' }, 400);
    const merged = new Uint8Array(head.length + value.length);
    merged.set(head);
    merged.set(value, head.length);
    nl = merged.indexOf(10, head.length);
    head = merged;
  }

  let meta;
  try {
    meta = JSON.parse(new TextDecoder().decode(head.subarray(0, nl)));
  } catch {
    return json({ error: '잘못된 요청입니다.' }, 400);
  }

  const to = [...new Set((Array.isArray(meta.to) ? meta.to : []).map(s => String(s).trim()).filter(Boolean))];
  const subject = String(meta.subject ?? '').replace(/[\r\n]+/g, ' ').trim();
  const text = String(meta.text ?? '');

  if (!to.length) return json({ error: '받는 사람 이메일을 입력해 주세요.' }, 400);
  if (to.length > MAX_TO) return json({ error: `받는 사람은 ${MAX_TO}명까지 가능합니다.` }, 400);
  const bad = to.find(a => !EMAIL.test(a) || a.length > 120);
  if (bad) return json({ error: `이메일 형식을 확인해 주세요: ${bad}` }, 400);
  if (!subject) return json({ error: '제목을 입력해 주세요.' }, 400);
  if (subject.length > 200 || text.length > 5000) return json({ error: '제목이나 내용이 너무 깁니다.' }, 400);

  const rest = head.subarray(nl + 1);
  if (rest.length && rest[0] !== 0x5b /* [ */) return json({ error: '잘못된 요청입니다.' }, 400);

  const replyTo = (env.CONTACT_TO || '').split(',')[0].trim();
  const mail = {
    from: env.CONTACT_FROM || 'Mantra Studio <onboarding@resend.dev>',
    to,
    subject,
    text: text || ' ',
    ...(replyTo && { reply_to: replyTo }),
  };

  // {...메일정보, "attachments": <브라우저가 보낸 배열>}
  const prefix = enc.encode(JSON.stringify(mail).slice(0, -1) + ',"attachments":');
  const suffix = enc.encode('}');
  const stream = new FixedLengthStream(prefix.length + (total - nl - 1) + suffix.length);
  const writer = stream.writable.getWriter();

  const pump = (async () => {
    await writer.write(prefix);
    if (rest.length) await writer.write(rest);
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      await writer.write(value);
    }
    await writer.write(suffix);
    await writer.close();
  })().catch(err => writer.abort(err).catch(() => {}));

  const failed = json({ error: '전송에 실패했습니다. 잠시 후 다시 시도해 주세요.' }, 502);
  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: stream.readable,
    });
    await pump;
    if (!res.ok) {
      const detail = await res.text();
      console.error('Resend 오류', res.status, detail);
      let message = '';
      try { message = JSON.parse(detail).message; } catch {}
      return json({ error: message ? `전송 실패: ${message}` : '전송에 실패했습니다.' }, 502);
    }
    const { id } = await res.json().catch(() => ({}));
    return json({ ok: true, id });
  } catch (err) {
    console.error('Resend 연결 실패', err);
    return failed;
  }
}
