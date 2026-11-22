// Kawan Keys — painel + API de validação. Sem dependências: só Node 18+.
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = Number(process.env.PORT || 3000);
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const DB_FILE = path.join(DATA_DIR, 'keys.json');
const PUBLIC_DIR = path.join(__dirname, 'public');
const LIFETIME_DAYS = 36500;

let ADMIN_PASSWORD = process.env.ADMIN_PASSWORD;
if (!ADMIN_PASSWORD) {
  ADMIN_PASSWORD = crypto.randomBytes(9).toString('base64url');
  console.log('\n⚠️  ADMIN_PASSWORD não definida. Senha temporária desta execução: ' + ADMIN_PASSWORD + '\n');
}
const SECRET = process.env.SESSION_SECRET || crypto.createHash('sha256').update('kawan:' + ADMIN_PASSWORD).digest('hex');

// ---------- Banco ----------
// Armazenamento PERMANENTE (recomendado): Upstash Redis via REST, grátis, sem instalar nada.
//   UPSTASH_REDIS_REST_URL e UPSTASH_REDIS_REST_TOKEN  → as keys ficam fora do Render e nunca somem num deploy.
// Sem essas variáveis, usa o arquivo keys.json (no Render grátis ele é apagado a cada deploy!).
const REMOTE_URL = (process.env.UPSTASH_REDIS_REST_URL || '').replace(/\/+$/, '');
const REMOTE_TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN || '';
const REMOTE_KEY = process.env.UPSTASH_DB_KEY || 'kawan:db';
const USE_REMOTE = !!(REMOTE_URL && REMOTE_TOKEN);

async function remoteCmd(cmd) {
  const r = await fetch(REMOTE_URL, {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + REMOTE_TOKEN, 'Content-Type': 'application/json' },
    body: JSON.stringify(cmd),
    signal: AbortSignal.timeout(15000),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || j.error) throw new Error(j.error || 'Upstash HTTP ' + r.status);
  return j.result;
}

fs.mkdirSync(DATA_DIR, { recursive: true });
let db = { keys: [] };
function normalizeDb() { if (!db || typeof db !== 'object' || !Array.isArray(db.keys)) db = { keys: [] }; }

// Escrita local (arquivo) com troca atômica
let saving = false, dirty = false;
function saveLocal() {
  dirty = true;
  if (saving) return;
  saving = true;
  setImmediate(function flush() {
    dirty = false;
    const tmp = DB_FILE + '.tmp';
    fs.writeFile(tmp, JSON.stringify(db, null, 2), (err) => {
      if (!err) fs.rename(tmp, DB_FILE, () => {});
      saving = false;
      if (dirty) saveLocal();
    });
  });
}

// Escrita remota: junta várias mudanças seguidas em uma só (a cada ~2s)
let remoteTimer = null, remoteBusy = false, remoteDirty = false;
async function flushRemote() {
  if (!USE_REMOTE) return;
  if (remoteBusy) { remoteDirty = true; return; }
  remoteBusy = true; remoteDirty = false;
  try { await remoteCmd(['SET', REMOTE_KEY, JSON.stringify(db)]); }
  catch (e) { console.error('Falha ao salvar no Upstash (vai tentar de novo):', e.message); remoteDirty = true; }
  remoteBusy = false;
  if (remoteDirty) { clearTimeout(remoteTimer); remoteTimer = setTimeout(flushRemote, 5000); }
}
function save() {
  saveLocal();
  if (USE_REMOTE && !remoteTimer) {
    remoteTimer = setTimeout(() => { remoteTimer = null; flushRemote(); }, 2000);
  }
}

// Carrega o banco ao iniciar. Se o armazenamento remoto falhar, NÃO sobe vazio (para não apagar nada).
async function loadDb() {
  if (!USE_REMOTE) {
    try { db = JSON.parse(fs.readFileSync(DB_FILE, 'utf8')); } catch (_) {}
    normalizeDb();
    return;
  }
  let lastErr;
  for (let i = 1; i <= 5; i++) {
    try {
      const raw = await remoteCmd(['GET', REMOTE_KEY]);
      if (raw) { db = JSON.parse(raw); normalizeDb(); }
      else {
        // primeira vez no Upstash: aproveita o arquivo local, se existir
        try { db = JSON.parse(fs.readFileSync(DB_FILE, 'utf8')); } catch (_) {}
        normalizeDb();
        await remoteCmd(['SET', REMOTE_KEY, JSON.stringify(db)]);
      }
      return;
    } catch (e) { lastErr = e; console.error('Upstash indisponível (tentativa ' + i + '/5): ' + e.message); await new Promise((r) => setTimeout(r, 2000 * i)); }
  }
  console.error('Não foi possível carregar as keys do Upstash. Encerrando para não perder dados.');
  throw lastErr;
}

// ---------- Utilidades ----------
const now = () => Math.floor(Date.now() / 1000);
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
function randomChunk(n) {
  const b = crypto.randomBytes(n);
  let s = '';
  for (let i = 0; i < n; i++) s += ALPHABET[b[i] % ALPHABET.length];
  return s;
}
function newKeyString(prefix) {
  let k;
  do { k = `${prefix}-${randomChunk(4)}-${randomChunk(4)}-${randomChunk(4)}`; }
  while (db.keys.some((x) => x.key === k));
  return k;
}
function status(k) {
  if (k.revoked) return 'revoked';
  if (k.expiresAt && now() >= k.expiresAt) return 'expired';
  return 'active';
}
const safeEq = (a, b) => {
  const ha = crypto.createHash('sha256').update(String(a)).digest();
  const hb = crypto.createHash('sha256').update(String(b)).digest();
  return crypto.timingSafeEqual(ha, hb);
};

// Rate limit simples em memória
const buckets = new Map();
function limited(id, max, windowMs) {
  const t = Date.now();
  let b = buckets.get(id);
  if (!b || t > b.reset) { b = { n: 0, reset: t + windowMs }; buckets.set(id, b); }
  b.n++;
  return b.n > max;
}
setInterval(() => { const t = Date.now(); for (const [k, v] of buckets) if (t > v.reset) buckets.delete(k); }, 60000).unref();

// Sessão: token assinado "exp.assinatura" em cookie HttpOnly
function sign(exp) { return crypto.createHmac('sha256', SECRET).update(String(exp)).digest('base64url'); }
function makeToken() { const exp = Date.now() + 12 * 3600 * 1000; return exp + '.' + sign(exp); }
function validToken(tok) {
  if (!tok) return false;
  const [exp, sig] = String(tok).split('.');
  if (!exp || !sig || Number(exp) < Date.now()) return false;
  return safeEq(sig, sign(exp));
}
function getCookie(req, name) {
  const c = req.headers.cookie || '';
  for (const part of c.split(';')) {
    const i = part.indexOf('=');
    if (i > 0 && part.slice(0, i).trim() === name) return decodeURIComponent(part.slice(i + 1).trim());
  }
  return null;
}
const isAdmin = (req) => validToken(getCookie(req, 'kw_session'));
const clientIp = (req) => (req.headers['x-forwarded-for'] || '').split(',')[0].trim() || req.socket.remoteAddress || '?';

function send(res, code, obj, headers = {}) {
  const body = JSON.stringify(obj);
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...headers });
  res.end(body);
}
function readBody(req, max = 100_000) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (c) => { data += c; if (data.length > max) { reject(new Error('grande')); req.destroy(); } });
    req.on('end', () => { try { resolve(data ? JSON.parse(data) : {}); } catch (e) { reject(e); } });
    req.on('error', reject);
  });
}
function publicKey(k) {
  return { id: k.id, key: k.key, note: k.note || '', admin: !!k.admin, hwidLock: !!k.hwidLock, hwid: k.hwid || null,
    createdAt: k.createdAt, expiresAt: k.expiresAt || null, revoked: !!k.revoked, lastUsedAt: k.lastUsedAt || null,
    uses: k.uses || 0, status: status(k) };
}
const clampDays = (d) => Math.min(LIFETIME_DAYS, Math.max(1, Math.floor(Number(d) || 0)));

// ---------- Rotas ----------
async function handleApi(req, res, url) {
  const route = url.pathname;

  // --- Validação pública (usada pelo script Lua) ---
  if (route === '/api/validate') {
    if (limited('v:' + clientIp(req), 90, 60000)) return send(res, 429, { valid: false, reason: 'rate_limit' });
    let key, hwid;
    if (req.method === 'GET') { key = url.searchParams.get('key'); hwid = url.searchParams.get('hwid'); }
    else if (req.method === 'POST') { const b = await readBody(req); key = b.key; hwid = b.hwid; }
    else return send(res, 405, { valid: false });
    key = String(key || '').trim().slice(0, 100);
    hwid = hwid ? String(hwid).trim().slice(0, 200) : null;
    const k = db.keys.find((x) => x.key === key);
    if (!k) return send(res, 200, { valid: false, reason: 'not_found' });
    const st = status(k);
    if (st !== 'active') return send(res, 200, { valid: false, reason: st });
    if (k.hwidLock) {
      if (!hwid) return send(res, 200, { valid: false, reason: 'hwid_required' });
      if (!k.hwid) k.hwid = hwid;
      else if (k.hwid !== hwid) return send(res, 200, { valid: false, reason: 'hwid_mismatch' });
    }
    k.lastUsedAt = now(); k.uses = (k.uses || 0) + 1; save();
    return send(res, 200, { valid: true, admin: !!k.admin, expiresAt: k.expiresAt || null, now: now() });
  }

  // --- Login / logout ---
  if (route === '/api/login' && req.method === 'POST') {
    const ip = clientIp(req);
    if (limited('l:' + ip, 8, 10 * 60000)) return send(res, 429, { error: 'Muitas tentativas. Aguarde alguns minutos.' });
    const b = await readBody(req);
    if (!safeEq(b.password || '', ADMIN_PASSWORD)) return send(res, 401, { error: 'Senha incorreta' });
    const secure = req.headers['x-forwarded-proto'] === 'https' ? '; Secure' : '';
    return send(res, 200, { ok: true }, { 'Set-Cookie': `kw_session=${makeToken()}; HttpOnly; SameSite=Strict; Path=/; Max-Age=43200${secure}` });
  }
  if (route === '/api/logout' && req.method === 'POST') {
    return send(res, 200, { ok: true }, { 'Set-Cookie': 'kw_session=; HttpOnly; SameSite=Strict; Path=/; Max-Age=0' });
  }

  // --- Daqui pra baixo: somente admin ---
  if (!isAdmin(req)) return send(res, 401, { error: 'Não autorizado' });

  if (route === '/api/admin/keys' && req.method === 'GET') {
    const list = db.keys.map(publicKey).sort((a, b) => b.createdAt - a.createdAt);
    return send(res, 200, { keys: list, now: now(), storage: USE_REMOTE ? 'remote' : 'file' });
  }

  // Backup: baixa todas as keys em um arquivo JSON
  if (route === '/api/admin/backup' && req.method === 'GET') {
    const body = JSON.stringify({ app: 'kawan-keys', exportedAt: now(), keys: db.keys }, null, 2);
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store',
      'Content-Disposition': 'attachment; filename="kawan-keys-backup.json"' });
    return res.end(body);
  }

  // Restaurar: soma ao banco as keys de um backup (não apaga nem duplica as que já existem)
  if (route === '/api/admin/restore' && req.method === 'POST') {
    const b = await readBody(req, 5_000_000);
    const list = Array.isArray(b.keys) ? b.keys : [];
    let added = 0, skipped = 0;
    for (const x of list) {
      const key = x && typeof x.key === 'string' ? x.key.trim().slice(0, 100) : '';
      if (!key || db.keys.some((y) => y.key === key)) { skipped++; continue; }
      const num = (v) => (Number.isFinite(Number(v)) && v !== null && v !== '' ? Number(v) : null);
      db.keys.push({
        id: typeof x.id === 'string' && /^[\w-]+$/.test(x.id) && !db.keys.some((y) => y.id === x.id) ? x.id : crypto.randomUUID(),
        key, note: String(x.note || '').slice(0, 120), admin: !!x.admin, hwidLock: !!x.hwidLock,
        hwid: x.hwid ? String(x.hwid).slice(0, 200) : null, createdAt: num(x.createdAt) || now(),
        expiresAt: num(x.expiresAt), revoked: !!x.revoked, uses: num(x.uses) || 0, lastUsedAt: num(x.lastUsedAt),
      });
      added++;
    }
    if (added) save();
    return send(res, 200, { added, skipped });
  }

  if (route === '/api/admin/keys' && req.method === 'POST') {
    const b = await readBody(req);
    const count = Math.min(100, Math.max(1, Math.floor(Number(b.count) || 1)));
    const prefix = String(b.prefix || 'KW').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 10) || 'KW';
    const lifetime = b.duration === 'lifetime';
    const created = [];
    for (let i = 0; i < count; i++) {
      const k = { id: crypto.randomUUID(), key: newKeyString(prefix), note: String(b.note || '').slice(0, 120),
        admin: !!b.admin, hwidLock: !!b.hwidLock, hwid: null, createdAt: now(),
        expiresAt: lifetime ? null : now() + clampDays(b.days) * 86400, revoked: false, uses: 0, lastUsedAt: null };
      db.keys.push(k); created.push(publicKey(k));
    }
    save();
    return send(res, 200, { created });
  }

  const m = route.match(/^\/api\/admin\/keys\/([\w-]+)(?:\/(renew|revoke|restore|reset-hwid|note|expiry))?$/);
  if (m) {
    const k = db.keys.find((x) => x.id === m[1]);
    if (!k) return send(res, 404, { error: 'Key não encontrada' });
    const action = m[2];

    if (!action && req.method === 'DELETE') {
      db.keys = db.keys.filter((x) => x.id !== k.id); save();
      return send(res, 200, { ok: true });
    }
    if (req.method !== 'POST') return send(res, 405, { error: 'Método inválido' });
    const b = await readBody(req);

    if (action === 'renew') {
      const days = clampDays(b.days);
      if (b.lifetime) k.expiresAt = null;
      else if (k.expiresAt === null || k.expiresAt === undefined) return send(res, 400, { error: 'Key já é vitalícia' });
      else k.expiresAt = Math.max(now(), k.expiresAt) + days * 86400;
      k.revoked = false;
    } else if (action === 'expiry') {
      k.expiresAt = b.lifetime ? null : now() + clampDays(b.days) * 86400;
    } else if (action === 'revoke') k.revoked = true;
    else if (action === 'restore') k.revoked = false;
    else if (action === 'reset-hwid') k.hwid = null;
    else if (action === 'note') k.note = String(b.note || '').slice(0, 120);
    else return send(res, 404, { error: 'Ação inválida' });
    save();
    return send(res, 200, { key: publicKey(k) });
  }

  return send(res, 404, { error: 'Rota não encontrada' });
}

const MIME = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.svg': 'image/svg+xml' };
const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost');
    if (url.pathname.startsWith('/api/')) return await handleApi(req, res, url);
    let file = url.pathname === '/' ? '/index.html' : url.pathname;
    const full = path.normalize(path.join(PUBLIC_DIR, file));
    if (!full.startsWith(PUBLIC_DIR)) { res.writeHead(403); return res.end(); }
    fs.readFile(full, (err, data) => {
      if (err) { res.writeHead(404); return res.end('Não encontrado'); }
      res.writeHead(200, { 'Content-Type': MIME[path.extname(full)] || 'application/octet-stream',
        'X-Content-Type-Options': 'nosniff', 'X-Frame-Options': 'DENY', 'Cache-Control': 'no-cache' });
      res.end(data);
    });
  } catch (e) {
    send(res, 400, { error: 'Requisição inválida' });
  }
});
// Ao receber o aviso de desligar (acontece em todo deploy do Render), grava o que estiver pendente
async function shutdown() {
  try { clearTimeout(remoteTimer); remoteTimer = null; await flushRemote(); } catch (_) {}
  process.exit(0);
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

loadDb().then(() => {
  server.listen(PORT, () => console.log(`Kawan Keys rodando em http://localhost:${PORT} — armazenamento: ${USE_REMOTE ? 'Upstash (permanente)' : 'arquivo local (TEMPORÁRIO no Render grátis)'} — ${db.keys.length} keys`));
}).catch((e) => { console.error(e); process.exit(1); });
