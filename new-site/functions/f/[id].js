// GET /f/<코드> : 받는 사람이 파일을 내려받는 페이지
import { getShare, isId, signDownloads } from '../../lib/supabase.js';

const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const mb = n => n < 1024 * 1024 ? Math.max(1, Math.round(n / 1024)) + 'KB' : (n / 1024 / 1024).toFixed(1) + 'MB';
const kDate = iso => new Intl.DateTimeFormat('ko-KR', { timeZone: 'Asia/Seoul', year: 'numeric', month: 'long', day: 'numeric' }).format(new Date(iso));

function page(title, body, status = 200) {
  const html = `<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>${esc(title)} · MANTRA STUDIO</title>
<style>
  :root { --fg:#111; --muted:#6b6b6b; --line:#e6e6e6; --soft:#f7f7f6; --accent:#d94b2b; }
  * { box-sizing:border-box; }
  body { margin:0; background:var(--soft); color:var(--fg); font-family:'Noto Sans KR',system-ui,sans-serif; line-height:1.6; word-break:keep-all; -webkit-font-smoothing:antialiased; }
  header { background:#fff; border-bottom:1px solid var(--line); }
  header div { max-width:600px; margin:0 auto; padding:0 20px; height:60px; display:flex; align-items:center; }
  header a { font-weight:700; letter-spacing:.08em; font-size:15px; color:inherit; text-decoration:none; }
  main { max-width:600px; margin:32px auto; padding:0 16px; }
  .card { background:#fff; border:1px solid var(--line); border-radius:16px; padding:28px; }
  h1 { font-size:20px; margin:0 0 4px; }
  .desc { margin:0 0 20px; color:var(--muted); font-size:14px; }
  ul { list-style:none; margin:0; padding:0; }
  li { display:flex; align-items:center; gap:12px; padding:12px 4px 12px 14px; border:1px solid var(--line); border-radius:12px; margin-bottom:8px; }
  .name { flex:1; min-width:0; overflow-wrap:anywhere; font-size:15px; }
  .size { display:block; color:var(--muted); font-size:13px; }
  .btn { flex:none; display:inline-block; background:var(--fg); color:#fff; border-radius:999px; padding:9px 20px; font-size:14px; font-weight:500; text-decoration:none; transition:background .2s; }
  .btn:hover { background:var(--accent); }
  .off { color:var(--muted); font-size:13px; padding-right:12px; }
  .note { margin:16px 0 0; color:var(--muted); font-size:13px; }
</style>
</head>
<body>
<header><div><a href="/">MANTRA STUDIO</a></div></header>
<main><div class="card">${body}</div></main>
</body>
</html>`;
  return new Response(html, {
    status,
    headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store', 'X-Robots-Tag': 'noindex' },
  });
}

const gone = () => page('파일을 찾을 수 없습니다', '<h1>파일을 찾을 수 없습니다</h1><p class="desc" style="margin:0">받을 수 있는 기간이 지났거나 주소가 잘못되었습니다. 보내신 분께 다시 요청해 주세요.</p>', 404);

export async function onRequestGet({ params, env }) {
  if (!isId(params.id)) return gone();

  let share, urls;
  try {
    share = await getShare(env, params.id);
    if (!share || new Date(share.expires_at) < new Date()) return gone();
    urls = await signDownloads(env, share.files);
  } catch (err) {
    console.error(err);
    return page('잠시 후 다시 시도해 주세요', '<h1>잠시 후 다시 시도해 주세요</h1><p class="desc" style="margin:0">파일 정보를 불러오지 못했습니다.</p>', 502);
  }

  const items = share.files.map((f, i) => `
    <li><span class="name">${esc(f.name)}<span class="size">${mb(f.size)}</span></span>${
      urls[i] ? `<a class="btn" href="${esc(urls[i])}">받기</a>` : '<span class="off">준비 안 됨</span>'
    }</li>`).join('');

  return page('파일 받기', `
    <h1>파일 받기</h1>
    <p class="desc">만트라 스튜디오에서 보낸 파일입니다. ${esc(kDate(share.expires_at))}까지 받을 수 있습니다.</p>
    <ul>${items}</ul>
    <p class="note">받기 버튼이 동작하지 않으면 이 페이지를 새로고침해 주세요.</p>`);
}
