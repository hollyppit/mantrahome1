// Solapi 메시지 발송 (알림톡 ATA / 네이버 톡톡 NSA)
// 환경변수: SOLAPI_API_KEY, SOLAPI_API_SECRET, SOLAPI_SENDER (등록된 발신번호)
//   알림톡: SOLAPI_KAKAO_PFID, SOLAPI_KAKAO_TEMPLATE_ID
//   네이버 톡톡: SOLAPI_NAVER_TALK_ID, SOLAPI_NAVER_TEMPLATE_ID

const enc = new TextEncoder();
const hex = buf => Array.from(new Uint8Array(buf), b => b.toString(16).padStart(2, '0')).join('');

async function authHeader(apiKey, apiSecret) {
  const date = new Date().toISOString();
  const salt = hex(crypto.getRandomValues(new Uint8Array(16)));
  const key = await crypto.subtle.importKey('raw', enc.encode(apiSecret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const signature = hex(await crypto.subtle.sign('HMAC', key, enc.encode(date + salt)));
  return `HMAC-SHA256 apiKey=${apiKey}, date=${date}, salt=${salt}, signature=${signature}`;
}

export const CHANNELS = {
  kakao: {
    label: '알림톡',
    env: ['SOLAPI_KAKAO_PFID', 'SOLAPI_KAKAO_TEMPLATE_ID'],
    message: (env, variables) => ({
      type: 'ATA',
      kakaoOptions: { pfId: env.SOLAPI_KAKAO_PFID, templateId: env.SOLAPI_KAKAO_TEMPLATE_ID, variables, disableSms: true },
    }),
  },
  naver: {
    label: '네이버 톡톡',
    env: ['SOLAPI_NAVER_TALK_ID', 'SOLAPI_NAVER_TEMPLATE_ID'],
    message: (env, variables) => ({
      type: 'NSA',
      naverOptions: { talkId: env.SOLAPI_NAVER_TALK_ID, templateId: env.SOLAPI_NAVER_TEMPLATE_ID, variables, disableSms: true },
    }),
  },
};

// 설정이 빠진 환경변수 이름 목록
export function missingEnv(env, channel) {
  return ['SOLAPI_API_KEY', 'SOLAPI_API_SECRET', 'SOLAPI_SENDER', ...CHANNELS[channel].env].filter(k => !env[k]);
}

// phones: ['01012345678', ...] → { sent, failed: [{ to, reason }] }
export async function sendTemplate(env, channel, phones, variables) {
  const from = env.SOLAPI_SENDER.replace(/\D/g, '');
  const messages = phones.map(to => ({ to, from, ...CHANNELS[channel].message(env, variables) }));

  const res = await fetch('https://api.solapi.com/messages/v4/send-many/detail', {
    method: 'POST',
    headers: {
      Authorization: await authHeader(env.SOLAPI_API_KEY, env.SOLAPI_API_SECRET),
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ messages }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    console.error('Solapi 오류', res.status, JSON.stringify(data));
    throw new Error(data.errorMessage || `Solapi 오류 (${res.status})`);
  }

  const failed = (data.failedMessageList || []).map(m => ({ to: m.to, reason: `${m.statusMessage} (${m.statusCode})` }));
  if (failed.length) console.error('Solapi 접수 실패', JSON.stringify(failed));
  return { sent: phones.length - failed.length, failed };
}
