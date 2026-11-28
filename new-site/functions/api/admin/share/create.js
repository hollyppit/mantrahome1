// POST /api/admin/share/create : 링크 전송용 임시 공유를 만들고 업로드 URL 발급
// 요청: { files: [{ name, size, type }] } → { id, expiresAt, uploads: [url] }
import { KEEP_DAYS, cleanupExpired, createShare, newId, signUpload } from '../../../../lib/supabase.js';

const json = (body, status = 200) => Response.json(body, { status });
const MAX_FILES = 20;
const MAX_FILE = 50 * 1024 * 1024; // Supabase 기본 파일당 한도

export async function onRequestPost({ request, env, waitUntil }) {
  let data;
  try {
    data = await request.json();
  } catch {
    return json({ error: '잘못된 요청입니다.' }, 400);
  }

  const files = Array.isArray(data?.files) ? data.files : [];
  if (!files.length) return json({ error: '보낼 파일을 넣어 주세요.' }, 400);
  if (files.length > MAX_FILES) return json({ error: `파일은 한 번에 ${MAX_FILES}개까지 가능합니다.` }, 400);
  const big = files.find(f => !(Number(f.size) <= MAX_FILE));
  if (big) return json({ error: `${big.name}: 파일 하나당 50MB까지 올릴 수 있습니다.` }, 400);

  const id = newId();
  const list = files.map((f, i) => {
    const name = String(f.name || 'file').slice(0, 200);
    // 저장소 경로에는 한글을 못 쓰므로 번호 + 확장자만
    const ext = (name.match(/\.([A-Za-z0-9]{1,8})$/) || [])[1]?.toLowerCase();
    return { path: `${id}/${i + 1}${ext ? '.' + ext : ''}`, name, size: Number(f.size), type: String(f.type || '').slice(0, 100) };
  });
  const expiresAt = new Date(Date.now() + KEEP_DAYS * 864e5).toISOString();

  try {
    const uploads = await Promise.all(list.map(f => signUpload(env, f.path)));
    await createShare(env, id, list, expiresAt);
    // 지난 파일 정리는 응답과 별개로
    waitUntil(cleanupExpired(env).catch(err => console.error('정리 실패', err)));
    return json({ id, expiresAt, uploads });
  } catch (err) {
    console.error(err);
    return json({ error: err.message.includes('SUPABASE_SERVICE_ROLE_KEY') ? '저장소 설정이 되어 있지 않습니다.' : '저장소 준비에 실패했습니다.' }, 502);
  }
}
