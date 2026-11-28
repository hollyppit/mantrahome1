// Supabase REST / Storage 를 service role 키로 호출 (서버 전용)
// 환경변수: SUPABASE_SERVICE_ROLE_KEY (필수), SUPABASE_URL (선택)

export const BUCKET = 'shared-files';
export const KEEP_DAYS = 14;

const base = env => (env.SUPABASE_URL || 'https://cxuhyaouqtnnebijuxcp.supabase.co').replace(/\/$/, '');

function headers(env, extra = {}) {
  const key = env.SUPABASE_SERVICE_ROLE_KEY;
  if (!key) throw new Error('SUPABASE_SERVICE_ROLE_KEY 환경변수가 없습니다.');
  // 예전 JWT 키(eyJ...)는 Authorization 에도, 새 sb_secret_ 키는 apikey 에만
  return { apikey: key, ...(key.startsWith('eyJ') && { Authorization: `Bearer ${key}` }), ...extra };
}

async function call(env, path, { method = 'GET', body, headers: extra } = {}) {
  const res = await fetch(`${base(env)}${path}`, {
    method,
    headers: headers(env, { ...(body !== undefined && { 'Content-Type': 'application/json' }), ...extra }),
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`Supabase ${method} ${path.split('?')[0]} ${res.status}: ${text.slice(0, 300)}`);
  return text ? JSON.parse(text) : null;
}

export function newId() {
  const abc = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
  const bytes = crypto.getRandomValues(new Uint8Array(12));
  return Array.from(bytes, b => abc[b % abc.length]).join('');
}

export const isId = id => /^[A-Za-z0-9]{12}$/.test(id || '');

export async function createShare(env, id, files, expiresAt) {
  await call(env, '/rest/v1/file_shares', {
    method: 'POST',
    body: { id, files, expires_at: expiresAt },
    headers: { Prefer: 'return=minimal' },
  });
}

export async function getShare(env, id) {
  const rows = await call(env, `/rest/v1/file_shares?id=eq.${encodeURIComponent(id)}&select=*`);
  return rows?.[0] || null;
}

// 업로드용 서명 URL (브라우저가 PUT 으로 직접 올림)
export async function signUpload(env, path) {
  const { url } = await call(env, `/storage/v1/object/upload/sign/${BUCKET}/${path}`, { method: 'POST', body: {} });
  return `${base(env)}/storage/v1${url}`;
}

// 내려받기용 서명 URL 여러 개 (download= 로 원래 파일 이름 지정)
export async function signDownloads(env, files, expiresIn = 3600) {
  const list = await call(env, `/storage/v1/object/sign/${BUCKET}`, {
    method: 'POST',
    body: { expiresIn, paths: files.map(f => f.path) },
  });
  return files.map(f => {
    const hit = list.find(x => x.path === f.path && x.signedURL);
    return hit ? `${base(env)}/storage/v1${hit.signedURL}&download=${encodeURIComponent(f.name)}` : null;
  });
}

// 기간 지난 공유와 파일 삭제
export async function cleanupExpired(env) {
  const now = new Date().toISOString();
  const rows = await call(env, `/rest/v1/file_shares?expires_at=lt.${now}&select=id,files&limit=50`);
  if (!rows?.length) return;
  const paths = rows.flatMap(r => (r.files || []).map(f => f.path));
  if (paths.length) await call(env, `/storage/v1/object/${BUCKET}`, { method: 'DELETE', body: { prefixes: paths } });
  await call(env, `/rest/v1/file_shares?id=in.(${rows.map(r => r.id).join(',')})`, { method: 'DELETE' });
}
