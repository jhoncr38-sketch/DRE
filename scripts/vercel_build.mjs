// Build da Vercel (vercel.json → buildCommand).
// Publica só o painel, como public/index.html, com a configuração do Supabase lida das
// variáveis de ambiente SUPABASE_URL e SUPABASE_ANON_KEY (ou SUPABASE_PUBLISHABLE_KEY).
// Sem as variáveis, publica em modo local (o painel funciona, mas não salva no banco).
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';

const ORIGEM = 'entregaveis/DRE_Dashboard.html';
const MARCA = '/*SUPABASE_CONFIG*/null';

const url = (process.env.SUPABASE_URL || '').trim().replace(/\/+$/, '');
const chave = (process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLISHABLE_KEY || '').trim();

let html = readFileSync(ORIGEM, 'utf8');
if (!html.includes(MARCA)) falhar(`o marcador ${MARCA} não está em ${ORIGEM} — gere o painel de novo (python src/gerar_dashboard.py).`);

if (url || chave) {
  if (!url || !chave) falhar('defina as duas variáveis: SUPABASE_URL e SUPABASE_ANON_KEY.');
  if (!/^https:\/\/[a-z0-9.-]+$/i.test(url)) falhar(`SUPABASE_URL inválida: "${url}" (esperado https://SEU-PROJETO.supabase.co).`);
  if (chaveSecreta(chave)) falhar('SUPABASE_ANON_KEY é uma chave SECRETA (service_role). Use a chave pública (anon ou publishable) e troque a secreta no Supabase.');
  html = html.replace(MARCA, () => JSON.stringify({ url, chave }).replace(/</g, '\\u003c'));
  console.log(`Painel publicado com o banco de dados: ${url}`);
} else {
  console.warn('Aviso: SUPABASE_URL e SUPABASE_ANON_KEY não estão definidas — painel publicado em modo local (não salva).');
}

mkdirSync('public', { recursive: true });
writeFileSync('public/index.html', html);

function chaveSecreta(k) {
  if (k.startsWith('sb_secret_')) return true;
  const partes = k.split('.');
  if (partes.length !== 3) return false;
  try { return JSON.parse(Buffer.from(partes[1], 'base64url').toString('utf8')).role === 'service_role'; }
  catch { return false; }
}
function falhar(msg) {
  console.error(`ERRO no build: ${msg}`);
  process.exit(1);
}
