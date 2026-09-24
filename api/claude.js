// Ponte entre o painel e a API da Claude (Vercel Function).
//
// Por que existe: a chave da API não pode viver no painel — o HTML é público e qualquer um a leria. Ela fica
// aqui, em variável de ambiente, e esta função só responde a quem apresentar uma sessão válida do Supabase e
// fizer parte da equipe (a mesma regra do resto do painel: sem membro, sem acesso).
//
// O que a função NÃO faz: gravar no banco. Ela devolve o que leu do documento; quem confere e grava é a pessoa,
// pela tela de sempre — assim a trilha de versões continua valendo.
//
// Variáveis de ambiente (Vercel → Settings → Environment Variables):
//   ANTHROPIC_API_KEY  chave da API (console.anthropic.com). Sem ela, a função responde 503 e o painel esconde o recurso.
//   SUPABASE_URL       a mesma do build, para validar a sessão de quem chama.
//   SUPABASE_ANON_KEY  idem (ou SUPABASE_PUBLISHABLE_KEY).

// Modelo: Opus 5 é o mais capaz e o padrão recomendado. Para leitura de documento simples, 'claude-sonnet-5'
// custa menos da metade ($2/$10 por milhão de tokens contra $5/$25) e costuma dar o mesmo resultado — trocar
// aqui é a única mudança necessária.
const MODELO = 'claude-opus-5';
const ESFORCO = 'low';                         // extração de campos não pede raciocínio longo
const LIMITE_ARQUIVO = 3 * 1024 * 1024;        // 3 MB de PDF já é muito para um PGDAS (o normal tem 100 KB)
const TIPOS = {pdf: 'application/pdf', png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', webp: 'image/webp'};

// O que pedimos que a Claude extraia. Vira o esquema da ferramenta: a resposta chega em JSON, não em texto solto.
const FERRAMENTA_PGDAS = {
  name: 'pgdas_extraido',
  description: 'Devolve os campos lidos de uma declaração do PGDAS-D (Simples Nacional).',
  input_schema: {
    type: 'object',
    properties: {
      competencia: {type: ['string', 'null'], description: 'Período de apuração no formato aaaa-mm, como aparece na declaração.'},
      cnpj: {type: ['string', 'null'], description: 'CNPJ do declarante, só dígitos.'},
      razao_social: {type: ['string', 'null']},
      receita_bruta_pa: {type: ['number', 'null'], description: 'Receita bruta do período de apuração, em reais.'},
      rbt12: {type: ['number', 'null'], description: 'Receita bruta dos últimos 12 meses (RBT12), em reais.'},
      das_total: {type: ['number', 'null'], description: 'Valor total do DAS, em reais.'},
      vencimento: {type: ['string', 'null'], description: 'Vencimento do DAS, aaaa-mm-dd.'},
      atividades: {
        type: 'array',
        description: 'Uma linha por atividade/anexo declarado.',
        items: {
          type: 'object',
          properties: {
            descricao: {type: ['string', 'null']},
            anexo: {type: ['string', 'null'], description: 'I, II, III, IV ou V.'},
            receita: {type: ['number', 'null'], description: 'Receita da atividade no período, em reais.'},
            aliquota_efetiva: {type: ['number', 'null'], description: 'Alíquota efetiva em porcentagem, como 8.03.'},
            icms_st: {type: ['boolean', 'null'],
              description: 'true quando esta receita está declarada com substituição tributária de ICMS (ICMS-ST).'},
            monofasico: {type: ['boolean', 'null'],
              description: 'true quando esta receita está declarada com tributação monofásica ou substituição de PIS/Cofins.'},
            iss_retido: {type: ['boolean', 'null'],
              description: 'true quando o ISS desta receita foi retido na fonte pelo tomador.'}
          }
        }
      },
      tributos: {
        type: 'array',
        description: 'Repartição do DAS por tributo, quando a declaração mostrar.',
        items: {
          type: 'object',
          properties: {nome: {type: ['string', 'null']}, valor: {type: ['number', 'null']}}
        }
      },
      observacoes: {type: ['string', 'null'], description: 'Algo relevante que não coube nos campos, em uma frase.'}
    },
    required: ['competencia', 'receita_bruta_pa', 'das_total', 'atividades']
  }
};

const INSTRUCAO_PGDAS =
  'Você lê declarações do PGDAS-D (Simples Nacional) e devolve os campos pedidos. Regras: copie o que está no ' +
  'documento, sem calcular nada e sem completar o que não estiver escrito; campo ausente vai como null. Valores ' +
  'em reais como número (1234.56), sem separador de milhar e sem símbolo. Alíquotas em porcentagem (8.03 para ' +
  '8,03%). Nas atividades, separe uma linha para cada combinação de atividade e situação tributária que a ' +
  'declaração mostrar, e marque icms_st, monofasico e iss_retido conforme o que estiver escrito (substituição ' +
  'tributária de ICMS, tributação monofásica ou substituição de PIS/Cofins, ISS retido na fonte); sem menção, ' +
  'deixe false. Se o documento não for um PGDAS, devolva tudo null e diga isso em observacoes.';

const ACOES = {
  pgdas: {ferramenta: FERRAMENTA_PGDAS, instrucao: INSTRUCAO_PGDAS, tokens: 2000,
          pergunta: 'Extraia os campos desta declaração do PGDAS-D.'}
};

export default async function handler(req, res) {
  if (req.method !== 'POST') return responder(res, 405, {erro: 'Use POST.'});

  const chave = (process.env.ANTHROPIC_API_KEY || '').trim();
  if (!chave) return responder(res, 503, {erro: 'A leitura de documentos não está configurada neste painel.'});

  const corpo = await lerCorpo(req);
  if (corpo.erro) return responder(res, corpo.status, {erro: corpo.erro});

  const {acao, arquivo} = corpo.dados || {};
  const receita = ACOES[acao];
  if (!receita) return responder(res, 400, {erro: 'Ação desconhecida.'});
  if (!arquivo || !arquivo.base64) return responder(res, 400, {erro: 'Envie o arquivo.'});

  const tipo = TIPOS[String(arquivo.nome || '').split('.').pop().toLowerCase()];
  if (!tipo) return responder(res, 415, {erro: 'Formato não aceito — envie PDF, PNG, JPG ou WEBP.'});
  if (arquivo.base64.length * 0.75 > LIMITE_ARQUIVO) return responder(res, 413, {erro: 'Arquivo grande demais (máximo 3 MB).'});

  // quem está chamando: sessão válida do Supabase e membro da equipe, como no resto do painel
  const quem = await conferirSessao(req.headers.authorization);
  if (!quem.ok) return responder(res, quem.status, {erro: quem.erro});

  const bloco = tipo === 'application/pdf'
    ? {type: 'document', source: {type: 'base64', media_type: tipo, data: arquivo.base64}}
    : {type: 'image', source: {type: 'base64', media_type: tipo, data: arquivo.base64}};

  let r;
  try {
    r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {'x-api-key': chave, 'anthropic-version': '2023-06-01', 'content-type': 'application/json'},
      body: JSON.stringify({
        model: MODELO,
        max_tokens: receita.tokens,
        output_config: {effort: ESFORCO},
        system: receita.instrucao,
        tools: [receita.ferramenta],
        tool_choice: {type: 'tool', name: receita.ferramenta.name},
        messages: [{role: 'user', content: [bloco, {type: 'text', text: receita.pergunta}]}]
      })
    });
  } catch (e) {
    return responder(res, 502, {erro: 'Não foi possível falar com a API da Claude.'});
  }

  const resposta = await r.json().catch(() => null);
  if (!r.ok) {
    const msg = resposta && resposta.error && resposta.error.message;
    console.error('claude:', r.status, msg || '');
    // 401/403 aqui é problema da chave do escritório, não de quem está usando o painel
    return responder(res, r.status === 429 ? 429 : 502,
      {erro: r.status === 429 ? 'A API da Claude está ocupada — tente de novo em instantes.'
                              : 'A API da Claude recusou o pedido. Confira a chave e o saldo da conta.'});
  }

  const uso = resposta && resposta.content && resposta.content.find(c => c.type === 'tool_use');
  if (!uso) return responder(res, 502, {erro: 'A resposta veio sem os campos esperados.'});
  return responder(res, 200, {dados: uso.input, uso: resposta.usage || null});
}

// --- sessão: o token é do Supabase, e a resposta diz se a pessoa é da equipe
async function conferirSessao(cabecalho) {
  const url = (process.env.SUPABASE_URL || '').trim().replace(/\/+$/, '');
  const anon = (process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_PUBLISHABLE_KEY || '').trim();
  if (!url || !anon) return {ok: false, status: 503, erro: 'Painel sem banco de dados configurado.'};

  const token = /^Bearer\s+(.+)$/i.exec(String(cabecalho || ''));
  if (!token) return {ok: false, status: 401, erro: 'Entre no painel para usar a leitura de documentos.'};

  const cabecalhos = {apikey: anon, Authorization: `Bearer ${token[1]}`};
  const usuario = await fetch(`${url}/auth/v1/user`, {headers: cabecalhos}).catch(() => null);
  if (!usuario || !usuario.ok) return {ok: false, status: 401, erro: 'Sua sessão expirou — entre de novo.'};

  // a tabela membros só é legível por quem é membro (RLS): lista vazia = não é da equipe
  const membros = await fetch(`${url}/rest/v1/membros?select=user_id&limit=1`, {headers: cabecalhos}).catch(() => null);
  const lista = membros && membros.ok ? await membros.json().catch(() => []) : null;
  if (!Array.isArray(lista) || !lista.length) return {ok: false, status: 403, erro: 'Seu usuário não faz parte da equipe do painel.'};
  return {ok: true};
}

async function lerCorpo(req) {
  if (req.body && typeof req.body === 'object') return {dados: req.body};
  let bruto = '';
  try {
    for await (const pedaco of req) {
      bruto += pedaco;
      if (bruto.length > LIMITE_ARQUIVO * 1.4) return {erro: 'Arquivo grande demais (máximo 3 MB).', status: 413};
    }
  } catch (e) { return {erro: 'Não foi possível ler o envio.', status: 400}; }
  try { return {dados: JSON.parse(bruto || '{}')}; }
  catch (e) { return {erro: 'Envio inválido.', status: 400}; }
}

function responder(res, status, corpo) {
  res.statusCode = status;
  res.setHeader('content-type', 'application/json; charset=utf-8');
  res.setHeader('cache-control', 'no-store');
  res.end(JSON.stringify(corpo));
}
