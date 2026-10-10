/* Bahnbrecher – Anbindung an Supabase
   Login per E-Mail-Code, Einladungslinks, Laden der Vereinsdaten, Live-Updates.
   Schreibt Änderungen, indem es den alten und neuen Zustand vergleicht (sync),
   damit die Oberfläche selbst kaum Backend-Code braucht. */
(function () {
  var URL = 'https://hxsvdvjcnqyggeagldob.supabase.co';
  var KEY = 'sb_publishable__RCufLMJuaYWoJxtzgPWlA_ckUbaRGy'; // öffentlicher Schlüssel, Rechte prüft die Datenbank
  var JOIN = 'bahnbrecher-join';
  var MEMBER_COLS = 'id,club_id,user_id,name,full_name,role,role_short,color,beitrag,is_admin,active,sort';
  var UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

  var sb = window.supabase.createClient(URL, KEY, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } });
  var c = null;         // die App-Komponente
  var club = null, me = null, channel = null, reloadT = null;

  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function todayISO() { var d = new Date(); return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  // App nutzt "TT.MM." bzw. "heute"
  function toShort(iso) { if (!iso) return ''; if (iso === todayISO()) return 'heute'; return iso.slice(8, 10) + '.' + iso.slice(5, 7) + '.'; }
  function err(e) { console.error(e); c.showToast('Nicht gespeichert: ' + ((e && e.message) || e)); scheduleReload(0); }
  function check(r) { if (r && r.error) throw r.error; return r ? r.data : null; }

  // Einladungslink ?join=… merken, bis die Person angemeldet ist
  var m = /[?&]join=([0-9a-f-]{36})/i.exec(location.search);
  if (m) { try { localStorage.setItem(JOIN, m[1]); } catch (e) {} history.replaceState(null, '', location.pathname); }

  function hasSession() {
    if (/access_token=|[?&]code=/.test(location.hash + location.search)) return true; // Rückkehr über den Anmeldelink
    try { return Object.keys(localStorage).some(function (k) { return /^sb-.*-auth-token$/.test(k); }); } catch (e) { return false; }
  }
  function pendingInvite() { try { return localStorage.getItem(JOIN); } catch (e) { return null; } }

  async function sendCode(email) {
    // Link in der Mail führt zurück in die App; eine offene Einladung reist im Link mit
    var inv = pendingInvite(), back = location.origin + location.pathname + (inv ? '?join=' + inv : '');
    var r = await sb.auth.signInWithOtp({ email: email, options: { shouldCreateUser: true, emailRedirectTo: back } });
    if (r.error) throw r.error;
  }
  async function verifyCode(email, code) {
    var r = await sb.auth.verifyOtp({ email: email, token: code, type: 'email' });
    if (r.error) throw r.error;
  }
  async function signOut() {
    if (channel) { sb.removeChannel(channel); channel = null; }
    club = null; me = null;
    await sb.auth.signOut();
  }

  // Nach dem Login: Einladung einlösen, Verein finden, Daten laden
  async function start(comp) {
    c = comp;
    var s = (await sb.auth.getSession()).data.session;
    if (location.hash.indexOf('access_token') >= 0) history.replaceState(null, '', location.pathname);
    if (!s) { c.remote({ screen: 'welcome', live: false }); return; }
    var inv = pendingInvite();
    if (inv) {
      var cr = await sb.rpc('claim_member', { token: inv });
      try { localStorage.removeItem(JOIN); } catch (e) {}
      if (cr.error) c.showToast(cr.error.message);
    }
    var rows = check(await sb.from('members').select(MEMBER_COLS).eq('user_id', s.user.id).eq('active', true));
    if (!rows.length) { c.remote({ screen: 'noclub', live: true, liveEmail: s.user.email }); return; }
    me = rows[0];
    club = check(await sb.from('clubs').select('*').eq('id', me.club_id).single());
    await reload(true);
    subscribe();
  }

  async function reload(first) {
    if (!club) return;
    var q = function (t, cols) { return sb.from(t).select(cols || '*').eq('club_id', club.id); };
    var res = await Promise.all([
      sb.from('members').select(MEMBER_COLS).eq('club_id', club.id).eq('active', true).order('sort'),
      q('rules').order('sort'), q('fines').order('created_at'), q('events').order('date'),
      q('rsvp_status'), q('rsvps'), q('attendance'), sb.from('clubs').select('*').eq('id', club.id).single()
    ]);
    var bad = res.find(function (r) { return r.error; });
    if (bad) { c.showToast('Laden fehlgeschlagen: ' + bad.error.message); return; }
    var members = res[0].data, rules = res[1].data, fines = res[2].data, events = res[3].data;
    var status = res[4].data, reasons = res[5].data, att = res[6].data;
    club = res[7].data;

    // Feste Listen der App in place ersetzen (werden überall im Code genutzt)
    MEMBERS.splice.apply(MEMBERS, [0, MEMBERS.length].concat(members.map(function (x) {
      return { id: x.id, name: x.name, full: x.full_name || x.name, role: x.role, roleShort: x.role_short };
    })));
    COLORS.splice.apply(COLORS, [0, COLORS.length].concat(members.map(function (x) { return x.color; })));
    GROUP.splice.apply(GROUP, [0, GROUP.length].concat(members.map(function (x) { return x.id; })));
    me = members.find(function (x) { return x.id === me.id; }) || me;

    var why = {}; reasons.forEach(function (r) { why[r.event_id + r.member_id] = r.reason; });
    var evs = events.map(function (e) {
      var d = parseISO(e.date), t = String(e.time).slice(0, 5), rs = {}, at = {};
      status.filter(function (r) { return r.event_id === e.id; }).forEach(function (r) { rs[r.member_id] = { s: r.status, reason: why[e.id + r.member_id] || '' }; });
      att.filter(function (a) { return a.event_id === e.id; }).forEach(function (a) { at[a.member_id] = a.status; });
      return { id: e.id, iso: e.date, wd: WD[d.getUTCDay()], day: pad(d.getUTCDate()), label: dLabel(d), time: t, title: e.title, place: e.place,
        deadline: mkDeadline(d, t, e.deadline_hours), frist: e.deadline_hours, rsvp: rs, att: at, series: e.series_id };
    });
    var patch = {
      live: true, clubId: club.id, clubName: club.name, me: me.id, admin: !!me.is_admin, rights: club.rights,
      beitragStd: String(club.beitrag_std),
      rules: rules.map(function (r) { return { id: r.id, name: r.name, amount: +r.amount, cat: r.cat, def: r.def, others: r.others, round: r.round, adopted: r.adopted, active: r.active }; }),
      fines: fines.map(function (f) { return { id: f.id, mid: f.member_id, rid: f.rule_id, name: f.name, amount: +f.amount, round: f.round, date: toShort(f.date), paid: f.paid,
        paidOn: f.paid_on === todayISO() ? 'heute' : undefined }; }),
      events: evs
    };
    if (first) Object.assign(patch, { screen: 'app', tab: 'start', overlay: null, players: members.map(function (x) { return x.id; }),
      exp: [], gastro: [], beitragInd: {}, settled: {}, adminPin: String(Math.random()).slice(2) });
    c.remote(patch);
  }

  function scheduleReload(ms) { clearTimeout(reloadT); reloadT = setTimeout(function () { reload(false); }, ms == null ? 400 : ms); }

  function subscribe() {
    if (channel) sb.removeChannel(channel);
    channel = sb.channel('club-' + club.id);
    ['fines', 'rsvps', 'attendance', 'events'].forEach(function (t) {
      channel.on('postgres_changes', { event: '*', schema: 'public', table: t, filter: 'club_id=eq.' + club.id }, function () { scheduleReload(); });
    });
    channel.subscribe();
  }

  // ---------- Änderungen der Oberfläche in die Datenbank schreiben ----------
  function byId(list) { var o = {}; (list || []).forEach(function (x) { o[x.id] = x; }); return o; }

  function sync(prev, st) {
    if (!club || !st.live) return;
    var jobs = [];
    if (prev.fines !== st.fines) jobs = jobs.concat(syncFines(prev.fines, st.fines));
    if (prev.events !== st.events) jobs = jobs.concat(syncEvents(prev.events, st.events, st.me));
    if (prev.rules !== st.rules) jobs = jobs.concat(syncRules(prev.rules, st.rules));
    if (prev.rights !== st.rights || prev.clubName !== st.clubName || prev.beitragStd !== st.beitragStd) {
      jobs.push(sb.from('clubs').update({ rights: st.rights, name: st.clubName, beitrag_std: parseFloat(String(st.beitragStd).replace(',', '.')) || 0 }).eq('id', club.id));
    }
    jobs.forEach(function (j) { Promise.resolve(j).then(function (r) { if (r && r.error) err(r.error); }, err); });
  }

  function syncFines(a, b) {
    var A = byId(a), B = byId(b), out = [], ins = [];
    b.forEach(function (f) {
      var o = A[f.id];
      if (!o) ins.push({ id: f.id, club_id: club.id, member_id: f.mid, rule_id: UUID.test(f.rid || '') ? f.rid : null, name: f.name, amount: f.amount,
        round: !!f.round, date: todayISO(), paid: !!f.paid, created_by: me.id });
      else if (o.paid !== f.paid) out.push(sb.from('fines').update({ paid: f.paid, paid_on: f.paid ? todayISO() : null }).eq('id', f.id));
    });
    if (ins.length) out.push(sb.from('fines').insert(ins));
    var del = a.filter(function (f) { return !B[f.id]; }).map(function (f) { return f.id; });
    if (del.length) out.push(sb.from('fines').delete().in('id', del));
    return out;
  }

  function syncEvents(a, b, mid) {
    var A = byId(a), out = [], ins = [];
    b.forEach(function (e) {
      var o = A[e.id];
      if (!o) {
        ins.push({ id: e.id, club_id: club.id, series_id: UUID.test(e.series || '') ? e.series : null, date: e.iso, time: e.time, title: e.title, place: e.place, deadline_hours: e.frist || 0 });
        return;
      }
      var r0 = (o.rsvp || {})[mid], r1 = (e.rsvp || {})[mid];
      if (r1 && (!r0 || r0.s !== r1.s || r0.reason !== r1.reason)) {
        out.push(sb.from('rsvps').upsert({ event_id: e.id, member_id: mid, club_id: club.id, status: r1.s, reason: r1.reason || '', updated_at: new Date().toISOString() }));
      }
      var at0 = o.att || {}, at1 = e.att || {};
      Object.keys(Object.assign({}, at0, at1)).forEach(function (k) {
        if ((at0[k] || '') === (at1[k] || '')) return;
        out.push(at1[k] ? sb.from('attendance').upsert({ event_id: e.id, member_id: k, club_id: club.id, status: at1[k] })
                        : sb.from('attendance').delete().eq('event_id', e.id).eq('member_id', k));
      });
    });
    if (ins.length) out.push(sb.from('events').insert(ins));
    var B = byId(b), del = a.filter(function (e) { return !B[e.id]; }).map(function (e) { return e.id; });
    if (del.length) out.push(sb.from('events').delete().in('id', del));
    return out;
  }

  function syncRules(a, b) {
    var A = byId(a), out = [];
    b.forEach(function (r, i) {
      var o = A[r.id], row = { name: r.name, amount: r.amount, cat: r.cat || 'Eigene', def: r.def || '', others: !!r.others, round: !!r.round, adopted: !!r.adopted, active: !!r.active };
      if (!o) out.push(sb.from('rules').insert(Object.assign({ id: r.id, club_id: club.id, sort: i }, row)));
      else if (['name', 'amount', 'cat', 'def', 'adopted', 'active'].some(function (k) { return o[k] !== r[k]; })) out.push(sb.from('rules').update(row).eq('id', r.id));
    });
    var B = byId(b), del = a.filter(function (r) { return !B[r.id]; }).map(function (r) { return r.id; });
    if (del.length) out.push(sb.from('rules').delete().in('id', del));
    return out;
  }

  window.Backend = { hasSession: hasSession, pendingInvite: pendingInvite, sendCode: sendCode, verifyCode: verifyCode, signOut: signOut, start: start, sync: sync, reload: reload };
})();
