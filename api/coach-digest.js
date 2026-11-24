const SUPABASE_URL = 'https://qsvhlsfutymvpwrmbtsb.supabase.co';
const SUPABASE_KEY = 'sb_publishable_J7aLsH4Y-D4JR0LVN-IFeg_l_aXjAiO';
const ONESIGNAL_APP_ID = 'ea0326eb-977e-4b7f-aaa1-ecf0f4cb355c';

async function sbFetch(path) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}` }
  });
  if (!res.ok) throw new Error(`Supabase ${res.status}: ${await res.text()}`);
  return res.json();
}

// Costa Rica es UTC-6 fijo (sin horario de verano).
function getCRDateStrings() {
  const now = new Date();
  const crNow = new Date(now.getTime() - 6 * 3600 * 1000);
  const crToday = crNow.toISOString().split('T')[0];
  const crTomorrow = new Date(crNow.getTime() + 24 * 3600 * 1000).toISOString().split('T')[0];
  return { crToday, crTomorrow };
}

// El resto de la app guarda session_date con new Date().toISOString().split('T')[0],
// que es la fecha calendario en UTC, no en hora CR. Un entreno terminado después de
// las 6pm CR ya queda fechado como "mañana" en UTC. Como este cron corre a las 9pm CR
// (03:00 UTC, todavía antes de la medianoche CR = 06:00 UTC), cualquier fila con
// session_date = crTomorrow en este momento SOLO puede ser un entreno de esta tarde/
// noche en CR — la fecha CR de mañana literalmente no empezó todavía. Por eso se
// consultan ambas fechas UTC para cubrir el día CR completo sin perder a nadie.
// LÍMITE ACEPTADO: este razonamiento depende de que el cron corra antes de las
// 06:00 UTC (medianoche CR) — hay ~3h de margen desde el horario programado
// (03:00 UTC). Vercel Hobby no garantiza el minuto exacto pero el retraso
// documentado es "dentro de la hora", así que el margen alcanza. Si algún día
// el cron corre con más de 3h de atraso, este día se reportaría con datos
// incompletos (no hay reintento retroactivo — cada corrida solo mira "hoy").
async function getClientsWhoTrainedToday(crToday, crTomorrow) {
  const sessions = await sbFetch(`workout_sessions?session_date=in.(${crToday},${crTomorrow})&select=client_id,plan_day_id`);
  return sessions;
}

async function isWeekComplete(clientId, weekNumber) {
  const weekPlanDays = await sbFetch(`monthly_plans?client_id=eq.${clientId}&week_number=eq.${weekNumber}&select=id`);
  if (!weekPlanDays.length) return false;
  const weekPlanDayIds = weekPlanDays.map(pd => pd.id);
  const idList = weekPlanDayIds.join(',');

  const doneIds = new Set();
  const weekSessions = await sbFetch(`workout_sessions?plan_day_id=in.(${idList})&select=plan_day_id`);
  weekSessions.forEach(s => doneIds.add(s.plan_day_id));

  const exs = await sbFetch(`exercises?plan_day_id=in.(${idList})&select=id,plan_day_id`);
  // Un plan_day sin ejercicios cargados no tiene nada que completar — se cuenta
  // como hecho de por sí, para que no bloquee el ⭐ de "semana completa" para siempre.
  const plandDayIdsWithExercises = new Set(exs.map(e => e.plan_day_id));
  weekPlanDayIds.forEach(id => { if (!plandDayIdsWithExercises.has(id)) doneIds.add(id); });
  if (exs.length > 0) {
    const exIds = exs.map(e => e.id).join(',');
    const logs = await sbFetch(`exercise_logs?exercise_id=in.(${exIds})&select=exercise_id`);
    const loggedExIds = new Set(logs.map(l => l.exercise_id));
    exs.forEach(e => { if (loggedExIds.has(e.id)) doneIds.add(e.plan_day_id); });
  }

  return weekPlanDayIds.every(id => doneIds.has(id));
}

async function getTestsCompletedToday(crToday, crTomorrow) {
  // completed_at es timestamptz real, se puede acotar directo con el rango horario
  // correcto de "hoy en CR" (a diferencia de session_date, no hace falta el truco de arriba).
  const startUTC = new Date(Date.parse(crToday + 'T00:00:00Z') + 6 * 3600 * 1000).toISOString();
  const endUTC = new Date(Date.parse(crTomorrow + 'T00:00:00Z') + 6 * 3600 * 1000).toISOString();
  return sbFetch(`tests?status=eq.completed&completed_at=gte.${encodeURIComponent(startUTC)}&completed_at=lt.${encodeURIComponent(endUTC)}&select=client_id`);
}

async function sbPost(path, rows, returnRep = false) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method: 'POST',
    headers: {
      apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}`, 'Content-Type': 'application/json',
      Prefer: returnRep ? 'return=representation' : 'return=minimal'
    },
    body: JSON.stringify(rows)
  });
  if (!res.ok) throw new Error(`Supabase ${res.status}: ${await res.text()}`);
  return returnRep ? res.json() : null;
}
async function sbPatch(path, row) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method: 'PATCH',
    headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}`, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
    body: JSON.stringify(row)
  });
  if (!res.ok) throw new Error(`Supabase ${res.status}: ${await res.text()}`);
}

// ---------- E9 · Nudge de inactividad (solo tier='entry') ----------
// Inactivo = más de 3 días sin un entreno de la semana habitual (fila en workout_sessions con
// plan_day_id; Run, hábitos, LIFT y comidas no cuentan). Si nunca entrenó, se cuenta desde
// client_onboarding.completed_at. Fuera: churn, ocultos y la pausa de pago activa (misma regla que
// el app: next_payment_date + 48 h desde el inicio de ese día en CR).
// Un mensaje por episodio (entry_nudges): no se repite hasta que haya un entreno posterior al
// registrado en el último nudge y vuelvan a pasar los 3 días.
const NUDGE_DAYS = 3;
function daysBetween(a, b) { return Math.round((Date.parse(b + 'T00:00:00Z') - Date.parse(a + 'T00:00:00Z')) / 86400000); }
function crDateOf(iso) { return new Date(Date.parse(iso) - 6 * 3600 * 1000).toISOString().slice(0, 10); }
function isPaused(c) {
  const d = String(c.next_payment_date || '').slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(d)) return false;
  return Date.now() >= Date.parse(d + 'T00:00:00-06:00') + 48 * 3600 * 1000;
}
function nudgeText(firstName, episode) {
  return episode === 1
    ? `${firstName} hey hace un par de días no te veo por acá, contame qué pasó, y qué vas a hacer para que no se siga repitiendo`
    : `${firstName} parece que otra vez no tenés actividad.. ¿cómo vamos a cambiarlo?`;
}
async function runNudges(crToday) {
  const clients = (await sbFetch(`clients?tier=eq.entry&select=id,name,is_churn,hidden,next_payment_date`))
    .filter(c => c.is_churn !== true && c.hidden !== true && !isPaused(c));
  if (!clients.length) return [];
  const ids = clients.map(c => c.id).join(',');
  const [onb, nudges] = await Promise.all([
    sbFetch(`client_onboarding?client_id=in.(${ids})&select=client_id,completed_at`),
    sbFetch(`entry_nudges?client_id=in.(${ids})&select=client_id,episode,last_training_date&order=episode.desc`)
  ]);
  const doneAt = Object.fromEntries(onb.filter(o => o.completed_at).map(o => [o.client_id, crDateOf(o.completed_at)]));
  const lastNudge = {};
  nudges.forEach(n => { if (!lastNudge[n.client_id]) lastNudge[n.client_id] = n; });
  const sent = [];
  for (const c of clients) {
    try {
      const s = await sbFetch(`workout_sessions?client_id=eq.${c.id}&plan_day_id=not.is.null&select=session_date&order=session_date.desc&limit=1`);
      const lastTrain = s.length ? String(s[0].session_date).slice(0, 10) : null;
      const base = lastTrain || doneAt[c.id];
      if (!base || daysBetween(base, crToday) <= NUDGE_DAYS) continue;
      const prev = lastNudge[c.id];
      // Mismo episodio: no entrenó desde el último nudge
      if (prev && (!lastTrain || (prev.last_training_date && lastTrain <= prev.last_training_date))) continue;
      const episode = (prev ? prev.episode : 0) + 1;
      // Primero se reserva el episodio (unique client_id+episode): si el cron corre dos veces, no hay doble mensaje
      const [row] = await sbPost('entry_nudges', [{ client_id: c.id, episode, last_training_date: lastTrain }], true);
      const first = String(c.name || '').trim().split(/\s+/)[0].toLowerCase();
      const [msg] = await sbPost('support_messages', [{ client_id: c.id, sender: 'coach', kind: 'text', tag: 'support', status: 'answered', body: nudgeText(first, episode) }], true);
      await sbPatch(`entry_nudges?id=eq.${row.id}`, { message_id: msg.id });
      const name = String(c.name || 'Cliente').trim();
      await sbPost('coach_feed', [{ kind: 'nudge', client_id: c.id, body: episode === 1 ? `${name} lleva 3+ días sin entrenar, se le escribió` : `${name} otra vez lleva 3+ días sin entrenar, se le escribió` }]);
      sent.push({ client_id: c.id, episode });
    } catch (e) {
      console.warn('coach-digest nudge:', c.id, e.message);
    }
  }
  return sent;
}

export default async function handler(req, res) {
  const auth = req.headers['authorization'] || '';
  if (auth !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    const { crToday, crTomorrow } = getCRDateStrings();

    let nudges = [];
    try { nudges = await runNudges(crToday); } catch (e) { console.warn('coach-digest nudges:', e.message); }

    const sessions = await getClientsWhoTrainedToday(crToday, crTomorrow);
    const trainedClientIds = [...new Set(sessions.map(s => s.client_id))];

    let trainedLines = [];
    if (trainedClientIds.length > 0) {
      const clientsData = await sbFetch(`clients?id=in.(${trainedClientIds.join(',')})&select=id,name`);
      const nameById = Object.fromEntries(clientsData.map(c => [c.id, c.name]));

      const planDayIds = [...new Set(sessions.map(s => s.plan_day_id).filter(Boolean))];
      const weekCompleteClientIds = new Set();
      if (planDayIds.length > 0) {
        const planDays = await sbFetch(`monthly_plans?id=in.(${planDayIds.join(',')})&select=id,client_id,week_number`);
        const weekKeys = [...new Set(planDays.map(pd => `${pd.client_id}::${pd.week_number}`))];
        for (const key of weekKeys) {
          const [clientId, weekNumberStr] = key.split('::');
          const complete = await isWeekComplete(clientId, parseInt(weekNumberStr, 10));
          if (complete) weekCompleteClientIds.add(clientId);
        }
      }

      trainedLines = trainedClientIds.map(id => {
        const name = nameById[id] || 'Cliente';
        return weekCompleteClientIds.has(id) ? `${name} ⭐ (semana completa)` : name;
      });
    }

    const completedTests = await getTestsCompletedToday(crToday, crTomorrow);
    let testNames = [];
    if (completedTests.length > 0) {
      const testClientIds = [...new Set(completedTests.map(t => t.client_id))];
      const clientsData = await sbFetch(`clients?id=in.(${testClientIds.join(',')})&select=id,name`);
      testNames = clientsData.map(c => c.name);
    }

    if (trainedLines.length === 0 && testNames.length === 0) {
      return res.status(200).json({ ok: true, sent: false, reason: 'nada que reportar hoy', nudges });
    }

    const bodyLines = [];
    if (trainedLines.length > 0) bodyLines.push(`💪 Entrenaron: ${trainedLines.join(', ')}`);
    if (testNames.length > 0) bodyLines.push(`✅ Evaluación completada: ${testNames.join(', ')}`);
    const message = bodyLines.join('\n');

    // Hilo "Coach" (E9): el resumen queda guardado aunque el push no llegue
    try { await sbPost('coach_feed', [{ kind: 'digest', body: message }]); } catch (e) { console.warn('coach-digest feed:', e.message); }

    const coaches = await sbFetch(`users?role=eq.coach&select=username&limit=1`);
    if (coaches.length === 0) {
      return res.status(200).json({ ok: true, sent: false, reason: 'no hay coach registrado', nudges });
    }

    const notifyBody = {
      app_id: ONESIGNAL_APP_ID,
      headings: { en: '📊 Resumen de hoy', es: '📊 Resumen de hoy' },
      contents: { en: message, es: message },
      filters: [{ field: 'tag', key: 'username', relation: '=', value: coaches[0].username }]
    };

    const onesignalRes = await fetch('https://onesignal.com/api/v1/notifications', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Basic ${process.env.ONESIGNAL_REST_API_KEY}` },
      body: JSON.stringify(notifyBody)
    });
    const onesignalData = await onesignalRes.json();
    if (!onesignalRes.ok) {
      return res.status(500).json({ error: onesignalData.errors?.[0] || 'Error OneSignal', nudges });
    }

    if (!onesignalData.recipients) {
      console.warn('coach-digest: OneSignal aceptó el envío pero recipients=0 — revisar que el coach tenga el tag username seteado (requiere haber aceptado push notifications en la app).');
    }
    return res.status(200).json({ ok: true, sent: true, message, recipients: onesignalData.recipients, nudges });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
}
