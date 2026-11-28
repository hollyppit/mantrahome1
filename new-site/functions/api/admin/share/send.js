// POST /api/admin/share/send : 올려 둔 파일의 다운로드 링크를 이메일 / 알림톡 / 네이버 톡톡으로 발송
// 요청: { id, channel: 'email' | 'kakao' | 'naver', to: [...], name?, subject?, text? }
import { getShare, isId } from '../../../../lib/supabase.js';
import { CHANNELS, missingEnv, sendTemplate } from '../../../../lib/solapi.js';

const json = (body, status = 200) => Response.json(body, { status });
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE = /^01\d{8,9}$/;
const MAX_TO = 10;

const kDate = iso => new Intl.DateTimeFormat('ko-KR', { timeZone: 'Asia/Seoul', year: 'numeric', month: 'long', day: 'numeric' }).format(new Date(iso));

function fileSummary(files) {
  let first = files[0].name;
  if (first.length > 30) first = first.slice(0, 29) + '…';
  return files.length > 1 ? `${first} 외 ${files.length - 1}개` : first;
}

export async function onRequestPost({ request, env }) {
  let data;
  try {
    data = await request.json();
  } catch {
    return json({ error: '잘못된 요청입니다.' }, 400);
  }

  const channel = data?.channel;
  if (channel !== 'email' && !CHANNELS[channel]) return json({ error: '보낼 방법을 골라 주세요.' }, 400);
  if (!isId(data.id)) return json({ error: '잘못된 요청입니다.' }, 400);

  const share = await getShare(env, data.id).catch(err => (console.error(err), undefined));
  if (share === undefined) return json({ error: '저장소에 연결하지 못했습니다.' }, 502);
  if (!share || new Date(share.expires_at) < new Date()) return json({ error: '파일을 찾을 수 없습니다. 다시 올려 주세요.' }, 404);

  const site = (env.SITE_URL || 'https://mantrastudio.cc').replace(/\/$/, '');
  const link = `${site}/f/${share.id}`;
  const until = kDate(share.expires_at);
  const name = String(data.name ?? '').replace(/[\r\n]+/g, ' ').trim().slice(0, 30);
  const rawTo = Array.isArray(data.to) ? data.to : [];

  if (channel === 'email') {
    const to = [...new Set(rawTo.map(s => String(s).trim()).filter(Boolean))];
    if (!to.length) return json({ error: '받는 사람 이메일을 입력해 주세요.' }, 400);
    if (to.length > MAX_TO) return json({ error: `받는 사람은 ${MAX_TO}명까지 가능합니다.` }, 400);
    const bad = to.find(a => !EMAIL.test(a) || a.length > 120);
    if (bad) return json({ error: `이메일 형식을 확인해 주세요: ${bad}` }, 400);
    const subject = String(data.subject ?? '').replace(/[\r\n]+/g, ' ').trim();
    const text = String(data.text ?? '').trim();
    if (!subject) return json({ error: '제목을 입력해 주세요.' }, 400);
    if (subject.length > 200 || text.length > 5000) return json({ error: '제목이나 내용이 너무 깁니다.' }, 400);
    if (!env.RESEND_API_KEY) return json({ error: '메일 설정이 되어 있지 않습니다.' }, 503);

    const body = [
      text,
      `아래 링크에서 파일을 받으실 수 있습니다. (${until}까지)`,
      link,
      share.files.map(f => `· ${f.name}`).join('\n'),
    ].filter(Boolean).join('\n\n');

    const replyTo = (env.CONTACT_TO || '').split(',')[0].trim();
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: env.CONTACT_FROM || 'Mantra Studio <onboarding@resend.dev>',
        to,
        subject,
        text: body,
        ...(replyTo && { reply_to: replyTo }),
      }),
    }).catch(err => (console.error('Resend 연결 실패', err), null));
    if (!res?.ok) {
      const detail = res ? await res.text() : '';
      if (res) console.error('Resend 오류', res.status, detail);
      let message = '';
      try { message = JSON.parse(detail).message; } catch {}
      return json({ error: message ? `전송 실패: ${message}` : '전송에 실패했습니다.' }, 502);
    }
    return json({ ok: true, link });
  }

  // 알림톡 / 네이버 톡톡
  const phones = [...new Set(rawTo.map(s => String(s).replace(/\D/g, '')).filter(Boolean))];
  if (!phones.length) return json({ error: '받는 사람 휴대폰 번호를 입력해 주세요.' }, 400);
  if (phones.length > MAX_TO) return json({ error: `받는 사람은 ${MAX_TO}명까지 가능합니다.` }, 400);
  const badPhone = phones.find(p => !PHONE.test(p));
  if (badPhone) return json({ error: `휴대폰 번호를 확인해 주세요: ${badPhone}` }, 400);

  const missing = missingEnv(env, channel);
  if (missing.length) {
    console.error('Solapi 환경변수 없음', missing);
    return json({ error: `${CHANNELS[channel].label} 설정이 아직 안 되어 있습니다. (${missing.join(', ')})` }, 503);
  }

  // 템플릿 변수 (README 의 템플릿 문구와 같아야 함)
  const variables = {
    '#{이름}': name || '고객',
    '#{파일}': fileSummary(share.files),
    '#{만료일}': until,
    '#{코드}': share.id,
  };

  try {
    const { sent, failed } = await sendTemplate(env, channel, phones, variables);
    if (!sent) return json({ error: `전송 실패: ${failed.map(f => `${f.to} ${f.reason}`).join(', ')}` }, 502);
    return json({ ok: true, link, sent, failed });
  } catch (err) {
    return json({ error: `전송 실패: ${err.message}` }, 502);
  }
}
