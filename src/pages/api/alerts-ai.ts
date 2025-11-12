import type { APIRoute } from 'astro';

export const prerender = false;

function heuristics(input: any): string[]{
  const stats = input?.stats || {};
  const cfg = input?.cfg || { thresholds: { lossStreak: 6, noVolo: 6, sinBjDealer: 3, windowSize: 10, doublesLossRate: 0.6, splitsLossRate: 0.6, pctTrendDelta: 15 } };
  const rows = Array.isArray(input?.rows) ? input.rows : [];
  const recos: string[] = [];
  try{
    if ((stats?.jugador?.rachas?.perdidas||0) >= (cfg?.thresholds?.lossStreak||6)) recos.push('Reduce tamaño de apuesta y considera pausa breve.');
    if ((stats?.diler?.rachas?.noVolo||0) >= (cfg?.thresholds?.noVolo||6)) recos.push('Probable vuelo del diler próximamente; ajusta tu toma de cartas con cautela.');
    if ((stats?.diler?.rachas?.sinBj||0) >= (cfg?.thresholds?.sinBjDealer||3)) recos.push('Sin BJ del diler en varias rondas; evita sobreexponerte esperando empates.');
    const N = Math.max(5, Math.floor(cfg?.thresholds?.windowSize||10));
    const recent = rows.slice(-N);
    const norm = (s: string)=> (s||'').trim().toUpperCase();
    const dbl = recent.filter((r:any) => norm(r.resultado).includes('DOBLADA'));
    const dblLoss = dbl.filter((r:any) => norm(r.resultado).includes('PERDI DOBLADA'));
    if (dbl.length>=3 && dblLoss.length/dbl.length >= (cfg?.thresholds?.doublesLossRate||0.6)) recos.push('Evita doblar temporalmente: ratio de pérdidas en dobles alto.');
    const spl = recent.filter((r:any) => norm(r.resultado).includes('DIVIDI'));
    const splLoss = spl.filter((r:any) => norm(r.resultado).includes('DIVIDI PERDI'));
    if (spl.length>=3 && splLoss.length/spl.length >= (cfg?.thresholds?.splitsLossRate||0.6)) recos.push('Evita dividir temporalmente: ratio de pérdidas en divisiones alto.');
    const win = (r:any) => ['GANE','GANE DOBLADA','DIVIDI GANE','BJ'].includes(norm(r.resultado));
    const pct = (n:number,t:number)=> t>0? Math.round((n*1000)/t)/10:0;
    const recentWinPct = pct(recent.filter(win).length, recent.length);
    const globalWinPct = pct(rows.filter(win).length, rows.length);
    const delta = Math.abs(recentWinPct - globalWinPct);
    if (delta >= (cfg?.thresholds?.pctTrendDelta||15)) recos.push(recentWinPct < globalWinPct ? 'La racha reciente es desfavorable; reduce exposición.' : 'Racha favorable reciente; mantén disciplina y evita sobreapuesta.');
  }catch{}
  return recos;
}

export const post: APIRoute = async ({ request }) => {
  try{
    const payload = await request.json();
    const key = import.meta.env.OPENAI_API_KEY;
    const model = import.meta.env.OPENAI_MODEL || 'gpt-4o-mini';
    const baseRecos = heuristics(payload);

    if (!key){
      return new Response(JSON.stringify({ recommendations: baseRecos }), { status: 200, headers: { 'Content-Type': 'application/json' } });
    }

    const sys = `Eres un asistente que sugiere 3 a 5 recomendaciones tácticas para Blackjack basadas en estadísticas y alertas. Evita sobreexposición, fomenta disciplina y gestión de riesgo. Devuelve una lista simple, clara, concisa. `;
    const user = {
      stats: payload?.stats || {},
      alerts: payload?.alerts || [],
      cfg: payload?.cfg || {}
    };

    const resp = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${key}` },
      body: JSON.stringify({
        model,
        messages: [
          { role: 'system', content: sys },
          { role: 'user', content: `Analiza y sugiere recomendaciones breves:
Stats: ${JSON.stringify(user.stats)}
Alerts: ${JSON.stringify(user.alerts)}
Config: ${JSON.stringify(user.cfg)}
` }
        ],
        temperature: 0.3,
      })
    });
    if (!resp.ok){
      return new Response(JSON.stringify({ recommendations: baseRecos }), { status: 200, headers: { 'Content-Type': 'application/json' } });
    }
    const data = await resp.json();
    const text = data?.choices?.[0]?.message?.content || '';
    const lines = text.split('\n').map((l:string)=> l.replace(/^[-•]\s*/, '').trim()).filter(Boolean);
    const merged = [...baseRecos, ...lines].slice(0,5);
    return new Response(JSON.stringify({ recommendations: merged }), { status: 200, headers: { 'Content-Type': 'application/json' } });
  }catch(e:any){
    return new Response(JSON.stringify({ error: e?.message || 'error', recommendations: heuristics({}) }), { status: 200, headers: { 'Content-Type': 'application/json' } });
  }
};