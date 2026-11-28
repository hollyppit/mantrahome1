// /api/admin/* 공통: X-Admin-Password 헤더를 ADMIN_PASSWORD 환경변수와 비교
// 비밀번호는 한글이 들어갈 수 있어 encodeURIComponent 로 인코딩해서 보냄

const enc = new TextEncoder();

async function same(a, b) {
  // 길이 차이로 정보가 새지 않게 해시끼리 상수 시간 비교
  const [x, y] = await Promise.all([a, b].map(s => crypto.subtle.digest('SHA-256', enc.encode(s))));
  return crypto.subtle.timingSafeEqual(x, y);
}

export async function onRequest({ request, env, next }) {
  if (!env.ADMIN_PASSWORD) {
    console.error('ADMIN_PASSWORD 환경변수가 없습니다.');
    return Response.json({ error: '관리자 비밀번호가 설정되지 않았습니다.' }, { status: 503 });
  }

  let pw = '';
  try {
    pw = decodeURIComponent(request.headers.get('X-Admin-Password') || '');
  } catch {}

  if (!pw || !(await same(pw, env.ADMIN_PASSWORD))) {
    // 무작위 대입을 느리게
    await new Promise(r => setTimeout(r, 1000));
    return Response.json({ error: '비밀번호가 맞지 않습니다.' }, { status: 401 });
  }

  return next();
}
