(() => {
    const root = document.getElementById('xsp-builder');
    const t = XS.t;
    const esc = XS.esc;
    const I = (name, size) => XS.icon(name, size || 16);
    const copy = (v) => JSON.parse(JSON.stringify(v === undefined ? null : v));
    const money = (n) => XS.money(n);
    const fx = (n) => (Number(n) || 0).toFixed(1);

    const TYPES = [
        { id: 'public', icon: 'parking' }, { id: 'job', icon: 'badge' }, { id: 'gang', icon: 'people' }, { id: 'private', icon: 'key' }, { id: 'impound', icon: 'tow' },
    ];
    const TYPE_LABEL = { public: 'Public garage', job: 'Job garage', gang: 'Gang garage', private: 'Private garage', impound: 'Impound lot', house: 'House garage' };
    const TYPE_SUB = {
        public: 'Anyone parks and takes out their own cars.',
        job: 'For one job. Personal cars, shared cars and a motor pool by rank.',
        gang: 'For one gang. Shared crew cars and a vehicle list.',
        private: 'One owner who buys or rents it, plus the people they pick.',
        impound: 'Where impounded and lost cars are paid out.',
    };
    const CATS = [['car', 'Cars and bikes'], ['boat', 'Boats'], ['air', 'Helicopters and planes'], ['any', 'Anything']];
    const CAT_ICON = { car: 'car', boat: 'boat', air: 'helicopter', any: 'stack' };
    const LOOKS = [['ped', 'An attendant'], ['prop', 'A pay machine'], ['marker', 'A marker'], ['none', 'Nothing']];
    const OPENS = { key: 'Walk up and press E', target: 'Target' };
    const LOG_KINDS = ['all', 'parking', 'impound', 'transfers', 'private', 'admin'];
    const STATUS = ['all', 'parked', 'out', 'impound', 'held', 'lost'];

    const S = {
        open: false, page: 'overview', garages: [], external: [], standard: [], stats: {}, system: {}, rights: {}, jobs: [], gangs: [], vehicles: [],
        me: {}, here: null, cur: null, curId: null, tab: 'general', dirty: false, busy: false, q: '', fType: 'all', fCat: 'all', overlay: null,
        logs: [], logKind: 'all', logQ: '', cars: [], carQ: '', carStatus: 'all', carGarage: '', impounds: [], ownerQ: '', ownerHits: [], ace: 'xs.garages.admin', command: 'garagebuilder',
    };

    const byId = (id) => S.garages.find((g) => String(g.id) === String(id));
    const pageEl = () => root.querySelector('#bx-page');
    const typeName = (k) => t(`gb_type_${k}`, null, TYPE_LABEL[k] || k);
    const catName = (k) => t(`gb_cat_${k}`, null, (CATS.find((c) => c[0] === k) || [k, k])[1]);
    const pt = (p) => (p ? `${fx(p.x)}, ${fx(p.y)}, ${fx(p.z)}` : '—');
    const allKeys = () => S.garages.map((g) => ({ key: g.data.key, label: g.data.label, type: g.data.type })).concat(S.external.map((e) => ({ key: e.key, label: e.label, type: 'house' })));

    function setPath(obj, path, value) {
        const parts = path.split('.');
        let node = obj;
        for (let i = 0; i < parts.length - 1; i++) {
            const k = /^\d+$/.test(parts[i]) ? Number(parts[i]) : parts[i];
            if (node[k] === undefined || node[k] === null || typeof node[k] !== 'object') node[k] = {};
            node = node[k];
        }
        const last = parts[parts.length - 1];
        node[/^\d+$/.test(last) ? Number(last) : last] = value;
    }

    function getPath(obj, path) {
        return path.split('.').reduce((n, k) => (n === undefined || n === null ? undefined : n[/^\d+$/.test(k) ? Number(k) : k]), obj);
    }

    function blank(type) {
        return {
            key: '', label: '', type, category: 'car', enabled: true, desks: [], drops: [], spawns: [], dropRadius: 0, display: false,
            look: { desk: 'ped', ped: '', scenario: '', prop: '', open: '' }, blip: { show: true, sprite: 0, colour: -1, label: '' },
            job: { name: '', grade: 0, duty: true }, gang: { name: '', grade: 0 }, personal: true, shared: true, fleet: [],
            fees: { takeOut: -1, park: -1, move: -1 }, private: { price: 50000, rent: 1500, slots: 4, buy: true, rentable: true }, impound: { lost: true },
            standard: '', notes: '',
        };
    }

    function normalise(d) {
        const b = blank(d.type || 'public');
        const out = Object.assign(b, d);
        ['look', 'blip', 'job', 'gang', 'fees', 'private', 'impound'].forEach((k) => { out[k] = Object.assign(b[k] || {}, d[k] || {}); });
        out.desks = XS.list(out.desks);
        out.drops = XS.list(out.drops);
        out.spawns = XS.list(out.spawns);
        out.fleet = XS.list(out.fleet).map((f) => Object.assign({ model: '', label: '', grade: 0, livery: -1, extras: [], color1: -1, color2: -1, tuned: false, plate: '', mode: 'borrow', price: 0, limit: 0 }, f, { extras: XS.list(f.extras) }));
        return out;
    }

    function issues(d) {
        const list = [];
        const add = (level, text, tab) => list.push({ level, text, tab });
        if (!d.desks.length) add('bad', t('gb_iss_desk', null, 'No desk, so nobody can open it'), 'points');
        if (!d.spawns.length) add('bad', t('gb_iss_spawn', null, 'No bay for cars to come out'), 'points');
        if (d.type !== 'impound' && !d.drops.length && !(d.display && d.spawns.length)) add('warn', t('gb_iss_drop', null, 'No parking spot, so nobody can park here'), 'points');
        if (d.type === 'job' && !d.job.name) add('bad', t('gb_iss_job', null, 'No job picked'), 'access');
        if (d.type === 'gang' && !d.gang.name) add('bad', t('gb_iss_gang', null, 'No gang picked'), 'access');
        if (d.type === 'private' && !d.private.buy && !d.private.rentable) add('warn', t('gb_iss_private', null, 'Can neither be bought nor rented'), 'money');
        if (d.display && d.spawns.length < 2) add('info', t('gb_iss_display', null, 'Show parked cars is on, with only one bay'), 'points');
        if (d.fleet.some((f) => !f.model)) add('warn', t('gb_iss_fleet', null, 'A vehicle in the list has no model'), 'fleet');
        if (d.spawns.length && d.desks.length) {
            const far = d.desks.every((a) => d.spawns.every((b) => Math.hypot(a.x - b.x, a.y - b.y) > 60));
            if (far && d.category === 'car') add('warn', t('gb_iss_far', null, 'The bays are far from the desk'), 'points');
        }
        if (d.enabled === false) add('info', t('gb_iss_off', null, 'Switched off'), 'general');
        return list;
    }

    function shell() {
        root.innerHTML = `
<div class="xsp-stage"><div class="bx bx-in">
  <div class="bx-lightbar"></div>
  <div class="bx-top">
    <div class="bx-logo"><svg class="bx-badge" viewBox="0 0 34 34"><defs><linearGradient id="gbG" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffd27a"/><stop offset="1" stop-color="#f2b33d"/></linearGradient></defs><rect x="1" y="1" width="32" height="32" rx="9" fill="#120f08" stroke="url(#gbG)" stroke-width="1.5"/><path d="M13 25V10h5.2a4.4 4.4 0 0 1 0 8.8H13" fill="none" stroke="url(#gbG)" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>
      <div class="bx-word"><b>XS-<span>Garages</span></b><small>${esc(t('gb_builder', null, 'Garage builder'))}</small></div></div>
    <button class="bx-search" data-act="palette">${I('search', 15)}<span class="bx-stext">${esc(t('gb_search', null, 'Search garages, settings and pages'))}</span><span class="bx-kbd">Ctrl</span><span class="bx-kbd">K</span></button>
    <span class="bx-sp"></span>
    <div class="bx-sys" id="bx-sys"></div>
    <button class="bx-iconbtn close" data-act="close" title="Esc">${I('close', 16)}</button>
  </div>
  <div class="bx-body">
    <nav class="bx-nav" id="bx-nav"></nav>
    <main class="bx-main"><div class="bx-page xsp-scroll" id="bx-page"></div></main>
  </div>
  <div id="bx-ov"></div>
</div></div>`;
    }

    function navItem(page, icon, label, count, warn) {
        const on = S.page === page || (page === 'garages' && S.page === 'edit');
        return `<button class="bx-navitem ${on ? 'on' : ''}" data-act="nav" data-page="${page}">${I(icon, 17)}<span class="bx-navlabel">${esc(label)}</span>${count !== undefined && count !== null ? `<span class="bx-count ${warn ? 'warn' : ''}">${esc(count)}</span>` : ''}</button>`;
    }

    function renderNav() {
        const nav = root.querySelector('#bx-nav');
        if (!nav) return;
        const bad = S.garages.filter((g) => issues(normalise(copy(g.data))).some((i) => i.level === 'bad')).length;
        const missing = S.standard.filter((s) => !s.added).length;
        const changed = XS.BuilderSettings && XS.BuilderSettings.changedCount ? XS.BuilderSettings.changedCount() : 0;
        nav.innerHTML = `
<div class="bx-navgroup">${esc(t('gb_nav_build', null, 'Build'))}</div>
${navItem('overview', 'chart', t('gb_overview', null, 'Overview'))}
${navItem('garages', 'parking', t('gb_garages', null, 'Garages'), S.garages.length, bad > 0)}
${navItem('standard', 'stack', t('gb_standard', null, 'Standard garages'), missing || null)}
${navItem('houses', 'home', t('gb_houses', null, 'House garages'), S.external.length || null)}
<div class="bx-navsep"></div>
<div class="bx-navgroup">${esc(t('gb_nav_run', null, 'Run'))}</div>
${navItem('vehicles', 'car', t('gb_vehicles', null, 'Vehicles'))}
${navItem('impound', 'tow', t('gb_impound', null, 'Impound'), (S.stats.impound || 0) + (S.stats.held || 0) || null)}
${navItem('logs', 'list', t('gb_logs', null, 'Logs'))}
${navItem('settings', 'sliders', t('gb_settings', null, 'Settings'), changed || null)}
${navItem('access', 'shield', t('gb_access', null, 'Access'))}
<div class="bx-me"><div class="bx-avatar">${esc(((S.me && S.me.name) || 'A').slice(0, 1).toUpperCase())}</div><div style="min-width:0"><b>${esc((S.me && S.me.name) || '')}</b><small>${esc(t('gb_admin', null, 'Builder access'))}</small></div></div>`;
    }

    function renderSys() {
        const el = root.querySelector('#bx-sys');
        if (!el) return;
        const s = S.system || {};
        const pill = (on, label) => `<span class="bx-pill ${on ? '' : 'off'}"><i></i>${esc(label)}</span>`;
        el.innerHTML = `${pill(!!s.keys, s.keys || t('gb_no_keys', null, 'No key script'))}${pill(!!s.housing, s.housing || t('gb_no_housing', null, 'No XS-Housing'))}${s.oldGarage ? `<span class="bx-pill off" style="color:#ff9aa3"><i style="background:#f0525f"></i>${esc(t('gb_old_running', { name: s.oldGarage }, `${s.oldGarage} is running`))}</span>` : ''}`;
    }

    function render() {
        renderNav();
        renderSys();
        const el = pageEl();
        if (!el) return;
        if (S.page !== 'settings' && XS.BuilderSettings) XS.BuilderSettings.unmount();
        const pages = { overview, garages: garagesPage, edit: editor, standard: standardPage, houses: housesPage, vehicles: vehiclesPage, impound: impoundPage, logs: logsPage, settings: () => '<div id="bx-setmount"></div>', access: accessPage };
        const top = el.scrollTop;
        el.innerHTML = (pages[S.page] || overview)();
        if (S.keepScroll) el.scrollTop = top;
        S.keepScroll = false;
        if (S.page === 'settings') XS.BuilderSettings.mount(el.querySelector('#bx-setmount'), () => renderNav());
        renderOverlay();
    }

    function head(title, sub, actions, crumb) {
        return `${crumb ? `<div class="bx-crumb">${crumb}</div>` : ''}<div class="bx-pagehead"><div><h1>${esc(title)}</h1>${sub ? `<p>${esc(sub)}</p>` : ''}</div><span class="bx-sp"></span>${actions || ''}</div>`;
    }

    function stat(cls, n, label, sub, icon, act) {
        return `<div class="bx-stat ${cls}" ${act || ''}>${I(icon, 18)}<b>${esc(n)}</b><span>${esc(label)}</span>${sub ? `<em>${esc(sub)}</em>` : ''}</div>`;
    }

    function overview() {
        const s = S.stats || {};
        const issueList = [];
        S.garages.forEach((g) => issues(normalise(copy(g.data))).forEach((i) => issueList.push(Object.assign({ id: g.id, label: g.data.label }, i))));
        const ready = S.garages.length ? Math.round((S.garages.filter((g) => !issues(normalise(copy(g.data))).some((i) => i.level === 'bad')).length / S.garages.length) * 100) : 0;
        const circ = 2 * Math.PI * 50;
        const sys = S.system || {};
        const sysRow = (label, value) => `<div class="bx-sysrow"><span>${esc(label)}</span><b class="${value ? '' : 'none'}">${esc(value || t('gb_none', null, 'none'))}</b></div>`;
        const order = { bad: 0, warn: 1, info: 2 };
        issueList.sort((a, b) => order[a.level] - order[b.level]);
        const by = s.byType || {};
        return `${head(t('gb_overview', null, 'Overview'), t('gb_overview_sub', null, 'Every garage, motor pool and impound lot on the server, and what still needs doing.'), `<button class="bx-btn" data-act="nav" data-page="standard">${I('stack', 15)}${esc(t('gb_standard', null, 'Standard garages'))}</button><button class="bx-btn primary" data-act="new" data-type="public">${I('plus', 15)}${esc(t('gb_new', null, 'New garage'))}</button>`)}
<div class="bx-ov">
  <div class="bx-card"><div class="bx-ready">
    <div class="bx-ring"><svg width="118" height="118"><defs><linearGradient id="bxRingGrad"><stop offset="0" stop-color="#ffd27a"/><stop offset="1" stop-color="#f2b33d"/></linearGradient></defs><circle class="track" cx="59" cy="59" r="50"/><circle class="fill" cx="59" cy="59" r="50" stroke-dasharray="${circ}" stroke-dashoffset="${circ * (1 - ready / 100)}"/></svg><div><b>${ready}%</b><small>${esc(t('gb_ready', null, 'ready'))}</small></div></div>
    <div class="bx-readytext"><h2>${esc(S.garages.length ? t('gb_ready_title', { n: S.garages.length }, `${S.garages.length} garages`) : t('gb_ready_empty', null, 'No garages yet'))}</h2>
      <p>${esc(S.garages.length ? t('gb_ready_sub', null, 'Fix the red ones first. Yellow and blue are worth a look.') : t('gb_ready_empty_sub', null, 'Add the standard GTA garages in one click, or build your own.'))}</p>
      ${issueList.length ? `<div class="bx-issues">${issueList.slice(0, 40).map((i) => `<div class="bx-issue ${i.level}" data-act="edit" data-id="${i.id}" data-tab="${esc(i.tab)}" style="cursor:pointer"><i>${I(i.level === 'bad' ? 'alert' : 'info', 13)}</i><div><b>${esc(i.text)}</b><span>#${i.id} · ${esc(i.label)}</span></div>${I('chevron', 14)}</div>`).join('')}</div>` : (S.garages.length ? `<div class="bx-allgood">${I('check', 16)}${esc(t('gb_all_good', null, 'Everything is set up.'))}</div>` : '')}
    </div></div></div>
  <div class="bx-stats">
    ${stat('green', s.parked || 0, t('gb_st_parked', null, 'Parked'), null, 'parking', 'data-act="carsby" data-status="parked"')}
    ${stat('amber', s.out || 0, t('gb_st_out', null, 'Out driving'), null, 'car', 'data-act="carsby" data-status="out"')}
    ${stat('red', (s.impound || 0) + (s.held || 0), t('gb_st_impound', null, 'Impounded or held'), null, 'tow', 'data-act="nav" data-page="impound"')}
    ${stat('', s.lost || 0, t('gb_st_lost', null, 'Missing'), t('gb_st_lost_sub', null, 'out, not in the world'), 'search', 'data-act="carsby" data-status="lost"')}
    ${stat('', `${by.public || 0} / ${by.impound || 0}`, t('gb_st_public', null, 'Public / impound lots'), null, 'parking', 'data-act="nav" data-page="garages"')}
    ${stat('', `${(by.job || 0) + (by.gang || 0)}`, t('gb_st_groups', null, 'Job and gang garages'), t('gb_st_fleet', { n: s.fleetOut || 0 }, `${s.fleetOut || 0} pool cars out`), 'badge', 'data-act="nav" data-page="garages"')}
    ${stat('', `${s.privateOwned || 0} / ${by.private || 0}`, t('gb_st_private', null, 'Private garages taken'), null, 'key', 'data-act="nav" data-page="garages"')}
    ${stat('green', money(s.weekFees || 0), t('gb_st_fees', null, 'Fees paid, 7 days'), null, 'cash', 'data-act="nav" data-page="logs"')}
    ${stat('', s.cars || 0, t('gb_st_cars', null, 'Owned cars'), null, 'car', 'data-act="nav" data-page="vehicles"')}
  </div>
</div>
<div class="bx-sec"><div class="bx-sectitle"><h2>${esc(t('gb_start', null, 'Start something'))}</h2></div>
  <div class="bx-quick" style="grid-template-columns:repeat(5,1fr)">
    ${TYPES.map((x) => `<button class="bx-tpl" data-act="new" data-type="${x.id}"><span class="bx-kindico">${I(x.icon, 18)}</span><div><b>${esc(typeName(x.id))}</b><span>${esc(t(`gb_type_${x.id}_sub`, null, TYPE_SUB[x.id]))}</span></div></button>`).join('')}
  </div></div>
<div class="bx-sec"><div class="bx-sectitle"><h2>${esc(t('gb_system', null, 'What XS-Garages found'))}</h2></div>
  <div class="bx-sysgrid">${sysRow('Framework', sys.framework)}${sysRow(t('gb_sys_keys', null, 'Car keys'), sys.keys)}${sysRow(t('gb_sys_banking', null, 'Banking'), sys.banking)}${sysRow(t('gb_sys_target', null, 'Target'), sys.target)}${sysRow('XS-Housing', sys.housing ? t('gb_sys_housing', null, 'house garages on') : null)}${sysRow('XS-PoliceSystem', sys.police ? t('gb_sys_police', null, 'its impound shows up here') : null)}${sysRow(t('gb_sys_phone', null, 'Phone'), sys.phone)}${sysRow(t('gb_sys_old', null, 'Old garage script'), sys.oldGarage ? t('gb_sys_old_stop', { name: sys.oldGarage }, `${sys.oldGarage}: stop it`) : null)}</div></div>`;
    }

    function filtered() {
        const q = S.q.trim().toLowerCase();
        return S.garages.filter((g) => {
            const d = g.data;
            if (S.fType !== 'all' && d.type !== S.fType) return false;
            if (S.fCat !== 'all' && d.category !== S.fCat) return false;
            if (!q) return true;
            return `${g.id} ${d.label} ${d.key} ${d.job && d.job.name} ${d.gang && d.gang.name} ${(g.owner && g.owner.name) || ''}`.toLowerCase().includes(q);
        });
    }

    function garagesPage() {
        const list = filtered();
        const chip = (id, label, on, attr) => `<button class="bx-btn xs ${on ? 'primary' : 'ghost'}" ${attr}="${id}">${esc(label)}</button>`;
        const rows = list.map((g) => {
            const d = normalise(copy(g.data));
            const iss = issues(d);
            const bad = iss.some((i) => i.level === 'bad');
            const who = d.type === 'job' ? (S.jobs.find((j) => j.name === d.job.name) || { label: d.job.name }).label : (d.type === 'gang' ? (S.gangs.find((j) => j.name === d.gang.name) || { label: d.gang.name }).label : (d.type === 'private' ? (g.owner ? g.owner.name : t('gb_for_lease', null, 'For lease')) : ''));
            return `<tr class="click ${d.enabled === false ? 'off' : ''}" data-act="edit" data-id="${g.id}">
                <td class="bx-mono" style="width:56px">#${g.id}</td>
                <td><b>${esc(d.label)}</b><div class="bx-hint bx-mono">${esc(d.key)}</div></td>
                <td>${esc(typeName(d.type))}${who ? `<div class="bx-hint">${esc(who)}</div>` : ''}</td>
                <td>${I(CAT_ICON[d.category] || 'car', 14)} ${esc(catName(d.category))}</td>
                <td class="bx-hint">${d.desks.length} ${esc(t('gb_desks_s', null, 'desks'))} · ${d.drops.length} ${esc(t('gb_spots_s', null, 'spots'))} · ${d.spawns.length} ${esc(t('gb_bays_s', null, 'bays'))}${d.display ? ` · ${esc(t('gb_shown', null, 'cars shown'))}` : ''}</td>
                <td class="r bx-mono">${g.parked || 0}</td>
                <td class="r">${bad ? `<span class="bx-chip bad">${I('alert', 12)}${iss.filter((i) => i.level === 'bad').length}</span>` : (d.enabled === false ? `<span class="bx-chip off">${esc(t('gb_off_short', null, 'Off'))}</span>` : `<span class="bx-chip ok">${I('check', 12)}</span>`)}</td>
                <td class="r" style="width:96px"><button class="bx-tool" data-act="tpg" data-id="${g.id}" title="${esc(t('gb_teleport', null, 'Teleport'))}">${I('goto', 14)}</button><button class="bx-tool" data-act="dup" data-id="${g.id}" title="${esc(t('gb_duplicate', null, 'Duplicate'))}">${I('copy', 14)}</button></td>
            </tr>`;
        }).join('');
        return `${head(t('gb_garages', null, 'Garages'), t('gb_garages_sub', null, 'Click a row to edit it. Changes are live as soon as you save.'), `<button class="bx-btn primary" data-act="new" data-type="public">${I('plus', 15)}${esc(t('gb_new', null, 'New garage'))}</button>`)}
<div class="bx-listbar"><div class="bx-filter">${I('search', 15)}<input class="bx-input" id="gb-q" value="${esc(S.q)}" placeholder="${esc(t('gb_filter', null, 'Name, key, job, owner or #id'))}"></div>
  ${chip('all', t('gb_all', null, 'All'), S.fType === 'all', 'data-ftype')}${TYPES.map((x) => chip(x.id, typeName(x.id), S.fType === x.id, 'data-ftype')).join('')}
  <span class="bx-sp"></span>${chip('all', t('gb_any_kind', null, 'Any vehicle'), S.fCat === 'all', 'data-fcat')}${CATS.slice(0, 3).map((c) => chip(c[0], catName(c[0]), S.fCat === c[0], 'data-fcat')).join('')}
</div>
${list.length ? `<div class="bx-card"><table class="bx-table"><thead><tr><th>#</th><th>${esc(t('gb_name', null, 'Name'))}</th><th>${esc(t('gb_type', null, 'Type'))}</th><th>${esc(t('gb_for', null, 'For'))}</th><th>${esc(t('gb_points', null, 'Points'))}</th><th class="r">${esc(t('gb_parked_col', null, 'Parked'))}</th><th class="r">${esc(t('gb_setup', null, 'Setup'))}</th><th></th></tr></thead><tbody>${rows}</tbody></table></div>`
        : `<div class="bx-empty">${I('parking', 30)}<b>${esc(t('gb_empty', null, 'Nothing here yet'))}</b><p>${esc(t('gb_empty_text', null, 'Make a garage, or add the standard ones.'))}</p></div>`}`;
    }

    function field(label, inner, hint) {
        return `<div class="bx-field"><label class="bx-label">${esc(label)}</label>${inner}${hint ? `<div class="bx-hint">${esc(hint)}</div>` : ''}</div>`;
    }

    function inp(path, opts) {
        opts = opts || {};
        const v = getPath(S.cur, path);
        return `<input class="bx-input ${opts.mono ? 'mono' : ''}" data-path="${path}" ${opts.list ? `list="${opts.list}"` : ''} value="${esc(v === null || v === undefined ? '' : v)}" ${opts.placeholder ? `placeholder="${esc(opts.placeholder)}"` : ''} ${opts.max ? `maxlength="${opts.max}"` : ''}>`;
    }

    function unit(path, u, opts) {
        opts = opts || {};
        const v = getPath(S.cur, path);
        return `<div class="bx-unit"><input type="number" data-path="${path}" data-num="1" value="${esc(v === null || v === undefined ? '' : v)}" ${opts.min !== undefined ? `min="${opts.min}"` : ''} ${opts.max !== undefined ? `max="${opts.max}"` : ''} step="${opts.step || 1}">${u ? `<em>${esc(u)}</em>` : ''}</div>`;
    }

    function sw(path, label, hint, disabled) {
        const v = getPath(S.cur, path);
        return `<div class="bx-rowline"><div><b>${esc(label)}</b>${hint ? `<div class="bx-hint">${esc(hint)}</div>` : ''}</div><span class="bx-switch ${v ? 'on' : ''} ${disabled ? 'dis' : ''}" data-act="${disabled ? '' : 'toggle'}" data-path="${path}"></span></div>`;
    }

    function sel(path, options, num) {
        const v = getPath(S.cur, path);
        return `<select class="bx-input" data-path="${path}" ${num ? 'data-num="1"' : ''}>${options.map((o) => `<option value="${esc(o[0])}" ${String(o[0]) === String(v) ? 'selected' : ''}>${esc(o[1])}</option>`).join('')}</select>`;
    }

    function grades(list, name) {
        const j = XS.list(list).find((x) => x.name === name);
        const g = j ? XS.list(j.grades) : [];
        if (!g.length) return Array.from({ length: 11 }, (_, i) => [i, String(i)]);
        return g.map((x) => [x.grade, `${x.grade} · ${x.label}`]);
    }

    const POINT_DEFS = [
        { key: 'desks', icon: 'person', colour: '#f2b33d', label: 'Desks', hint: 'Where players walk up to open the garage. An attendant, a pay machine or a marker stands here.' },
        { key: 'drops', icon: 'parking', colour: '#4f9dff', label: 'Parking spots', hint: 'Drive into one of these and press E to park. The radius is on the right.' },
        { key: 'spawns', icon: 'car', colour: '#2fcf8a', label: 'Bays', hint: 'Where cars come out. Placed with a ghost car so you can see it fits. The first free bay is used.' },
    ];

    function pointRow(kind, p, i) {
        return `<div class="bx-pt"><span class="bx-ptn">${i + 1}</span><div class="bx-ptmain"><b>${esc(t(`gb_pt_${kind}_one`, { n: i + 1 }, `${({ desks: 'Desk', drops: 'Spot', spawns: 'Bay' })[kind]} ${i + 1}`))}</b><small>${esc(pt(p))} · ${Math.round(p.w || 0)}°</small></div>
            <div class="bx-ptacts"><button class="bx-tool" data-act="ptgo" data-kind="${kind}" data-i="${i}" title="${esc(t('gb_teleport', null, 'Teleport'))}">${I('goto', 13)}</button><button class="bx-tool" data-act="ptre" data-kind="${kind}" data-i="${i}" title="${esc(t('gb_move', null, 'Move'))}">${I('crosshair', 13)}</button><button class="bx-tool danger" data-act="ptdel" data-kind="${kind}" data-i="${i}" title="${esc(t('gb_remove', null, 'Remove'))}">${I('remove', 13)}</button></div></div>`;
    }

    function pointGroup(def) {
        const list = S.cur[def.key];
        return `<div class="bx-group"><div class="bx-grouph"><span class="bx-gico" style="background:${def.colour}">${I(def.icon, 16)}</span><div class="bx-gtext"><b>${esc(t(`gb_pt_${def.key}`, null, def.label))} ${list.length ? `<span class="bx-tag ok">${list.length}</span>` : ''}</b><span>${esc(t(`gb_pt_${def.key}_hint`, null, def.hint))}</span></div></div>
        <div class="bx-points">${list.map((p, i) => pointRow(def.key, p, i)).join('')}</div>
        <div class="bx-addrow"><button class="bx-btn sm" data-act="ptadd" data-kind="${def.key}">${I('crosshair', 14)}${esc(t('gb_place', null, 'Place'))}</button><button class="bx-btn sm" data-act="pthere" data-kind="${def.key}">${I('pin', 14)}${esc(def.key === 'spawns' ? t('gb_here_car', null, 'Where my car is') : t('gb_here', null, 'At my feet'))}</button>${def.key === 'drops' && S.cur.spawns.length ? `<button class="bx-btn sm ghost" data-act="dropsfromspawns">${I('copy', 14)}${esc(t('gb_drops_from_bays', null, 'Use the bays'))}</button>` : ''}</div></div>`;
    }

    function tabGeneral() {
        const d = S.cur;
        return `<div class="bx-layout"><div>
<div class="bx-card"><div class="bx-cardbody">
  <div class="bx-cols2">${field(t('gb_name', null, 'Name'), inp('label', { max: 48, placeholder: t('gb_name_ph', null, 'Legion Square Parking') }))}${field(t('gb_type', null, 'Type'), sel('type', TYPES.map((x) => [x.id, typeName(x.id)])))}</div>
  <div class="bx-cols2">${field(t('gb_key', null, 'Garage key'), inp('key', { max: 50, mono: true, placeholder: 'legionsquare' }), t('gb_key_hint', null, 'Saved on every car parked here. Other scripts and old qb-garages names use it. Letters, numbers, _ and - only.'))}${field(t('gb_category', null, 'Vehicles'), sel('category', CATS.map((c) => [c[0], catName(c[0])])))}</div>
  ${field(t('gb_notes', null, 'Staff notes'), `<textarea class="bx-input" data-path="notes" rows="3" style="height:auto;padding:9px 11px" maxlength="400">${esc(d.notes || '')}</textarea>`)}
</div></div>
</div><div>
<div class="bx-card"><div class="bx-cardbody">
  ${sw('enabled', t('gb_live', null, 'Live'), t('gb_live_hint', null, 'Off hides it everywhere without deleting it. Cars inside stay put.'))}
  ${sw('display', t('gb_display', null, 'Show parked cars'), t('gb_display_hint', null, 'Parked cars stay in their bays for everyone to see. Owners walk up and take them out.'))}
  ${d.type === 'impound' ? sw('impound.lost', t('gb_lost_here', null, 'Hand back missing cars'), t('gb_lost_here_hint', null, 'Cars that went missing out on the road can be paid out here too.')) : ''}
</div></div>
<div class="bx-card" style="margin-top:14px"><div class="bx-cardhead"><h3>${esc(t('gb_what_is', { type: typeName(d.type) }, typeName(d.type)))}</h3></div><div class="bx-cardbody"><div class="bx-hint" style="font-size:12.5px;line-height:1.55">${esc(t(`gb_type_${d.type}_long`, null, TYPE_SUB[d.type]))}</div></div></div>
</div></div>`;
    }

    function tabPoints() {
        const d = S.cur;
        return `<div class="bx-layout"><div>
${pointGroup(POINT_DEFS[0])}
<div style="height:14px"></div>
${pointGroup(POINT_DEFS[1])}
</div><div>
${pointGroup(POINT_DEFS[2])}
<div class="bx-card" style="margin-top:14px"><div class="bx-cardbody">
  ${field(t('gb_radius', null, 'Parking spot radius'), unit('dropRadius', 'm', { min: 0, max: 40, step: 0.5 }), t('gb_radius_hint', null, '0 uses the setting. Boats and aircraft get 20 m extra.'))}
  ${sw('display', t('gb_display', null, 'Show parked cars'), t('gb_display_hint2', null, 'Uses the bays as parking spaces. Drive into a bay to park there.'))}
  <button class="bx-btn sm" data-act="showpts" ${d.desks.length + d.drops.length + d.spawns.length ? '' : 'disabled'}>${I('eye', 14)}${esc(t('gb_show_points', null, 'Show me all points'))}</button>
</div></div>
</div></div>`;
    }

    function tabAccess() {
        const d = S.cur;
        if (d.type === 'job' || d.type === 'gang') {
            const list = d.type === 'job' ? S.jobs : S.gangs;
            const base = d.type;
            return `<div class="bx-layout"><div><div class="bx-card"><div class="bx-cardbody">
  <div class="bx-cols2">${field(base === 'job' ? t('gb_job', null, 'Job') : t('gb_gang', null, 'Gang'), `<select class="bx-input" data-path="${base}.name"><option value="">—</option>${XS.list(list).map((j) => `<option value="${esc(j.name)}" ${j.name === d[base].name ? 'selected' : ''}>${esc(j.label)}</option>`).join('')}</select>`)}${field(t('gb_min_grade', null, 'Lowest rank'), sel(`${base}.grade`, grades(list, d[base].name), true))}</div>
  ${base === 'job' ? sw('job.duty', t('gb_duty', null, 'Must be on duty'), null) : ''}
</div></div></div><div><div class="bx-card"><div class="bx-cardbody">
  ${sw('personal', t('gb_personal', null, 'Members park their own cars'), t('gb_personal_hint', null, 'Their personal cars can live here as well.'))}
  ${sw('shared', t('gb_shared', null, 'Shared cars'), t('gb_shared_hint', null, 'Cars members leave for the crew show up here for everyone in it.'))}
</div></div></div></div>`;
        }
        if (d.type === 'private') {
            const rec = byId(S.curId);
            const owner = rec && rec.owner;
            return `<div class="bx-layout"><div><div class="bx-card"><div class="bx-cardhead"><h3>${esc(t('gb_owner', null, 'Owner'))}</h3></div><div class="bx-cardbody">
  ${owner ? `<div class="bx-rowline"><div><b>${esc(owner.name)}</b><div class="bx-hint">${esc(owner.kind === 'rented' ? t('gb_renting_until', { date: XS.date(owner.paidUntil) }, `Renting, paid until ${XS.date(owner.paidUntil)}`) : t('gb_owns', null, 'Owns it'))} · ${esc(owner.cid)}</div></div>${S.rights.owners ? `<button class="bx-btn sm danger" data-act="ownerclear">${esc(t('gb_evict', null, 'Take it back'))}</button>` : ''}</div>
  ${XS.list(owner.access).length ? `<div class="bx-hint" style="margin-top:8px">${esc(t('gb_access_list', null, 'Also has a key:'))} ${XS.list(owner.access).map((a) => esc(a.name || a.cid)).join(', ')}</div>` : ''}` : `<div class="bx-hint">${esc(S.curId ? t('gb_no_owner', null, 'Nobody owns it. It is for lease at the desk.') : t('gb_save_first', null, 'Save the garage first.'))}</div>`}
</div></div></div><div>
${S.curId && S.rights.owners ? `<div class="bx-card"><div class="bx-cardhead"><h3>${esc(t('gb_set_owner', null, 'Give it to someone'))}</h3></div><div class="bx-cardbody">
  <div class="bx-filter">${I('search', 15)}<input class="bx-input" id="gb-ownerq" value="${esc(S.ownerQ)}" placeholder="${esc(t('gb_player_search', null, 'Online player name, citizen id or server id'))}"></div>
  <div class="bx-points" style="margin-top:8px">${S.ownerHits.map((p) => `<div class="bx-pt"><span class="bx-ptn">${esc(p.id)}</span><div class="bx-ptmain"><b>${esc(p.name)}</b><small>${esc(p.cid)}</small></div><div class="bx-ptacts"><button class="bx-btn xs" data-act="ownerset" data-pid="${p.id}" data-kind="owned">${esc(t('gb_give_owned', null, 'Owns'))}</button><button class="bx-btn xs ghost" data-act="ownerset" data-pid="${p.id}" data-kind="rented">${esc(t('gb_give_rented', null, 'Rents'))}</button></div></div>`).join('')}</div>
</div></div>` : ''}
</div></div>`;
        }
        return `<div class="bx-card"><div class="bx-cardbody"><div class="bx-hint">${esc(d.type === 'impound' ? t('gb_access_impound', null, 'Anyone can come here to pay for their own impounded or missing cars.') : t('gb_access_public', null, 'Anyone can use a public garage for their own cars.'))}</div></div></div>`;
    }

    function tabMoney() {
        const d = S.cur;
        return `<div class="bx-layout"><div>
<div class="bx-card"><div class="bx-cardhead"><h3>${esc(t('gb_fees', null, 'Fees here'))}</h3></div><div class="bx-cardbody">
  <div class="bx-cols3">${field(t('gb_fee_take', null, 'Taking out'), unit('fees.takeOut', '$', { min: -1, step: 10 }))}${field(t('gb_fee_park', null, 'Parking'), unit('fees.park', '$', { min: -1, step: 10 }))}${field(t('gb_fee_move', null, 'Moving a car here'), unit('fees.move', '$', { min: -1, step: 10 }))}</div>
  <div class="bx-hint">${esc(t('gb_fee_hint', null, '-1 uses the setting from Settings › Parking. Impound fees are set by the officer.'))}</div>
</div></div></div><div>
${d.type === 'private' ? `<div class="bx-card"><div class="bx-cardhead"><h3>${esc(t('gb_private_money', null, 'Buying and renting'))}</h3></div><div class="bx-cardbody">
  ${sw('private.buy', t('gb_can_buy', null, 'Can be bought'))}
  ${d.private.buy ? field(t('gb_price', null, 'Price'), unit('private.price', '$', { min: 0, step: 1000 })) : ''}
  ${sw('private.rentable', t('gb_can_rent', null, 'Can be rented'))}
  ${d.private.rentable ? field(t('gb_rent', null, 'Rent each period'), unit('private.rent', '$', { min: 0, step: 50 }), t('gb_rent_hint', null, 'The period is in Settings › Private garages.')) : ''}
  ${field(t('gb_slots', null, 'Spaces'), unit('private.slots', '', { min: 1, max: 100 }), t('gb_slots_hint', null, 'How many cars fit inside.'))}
</div></div>` : ''}
</div></div>`;
    }

    function tabFleet() {
        const d = S.cur;
        const list = d.type === 'job' ? S.jobs : S.gangs;
        const gopts = grades(list, d[d.type] && d[d.type].name);
        const row = (f, i) => `<div class="bx-group" style="margin-bottom:10px"><div class="bx-grouph"><span class="bx-gico" style="background:#3a78f8">${I('car', 16)}</span><div class="bx-gtext"><b>${esc(f.label || f.model || t('gb_fleet_new', null, 'New vehicle'))} <span class="bx-tag">${esc(f.mode === 'buy' ? t('gb_mode_buy', null, 'Bought') : t('gb_mode_borrow', null, 'Borrowed'))}</span></b><span>${esc(f.model || '—')}${f.plate ? ` · ${esc(f.plate)}…` : ''}</span></div><span class="bx-sp"></span><button class="bx-tool" data-act="fleetdup" data-i="${i}" title="${esc(t('gb_duplicate', null, 'Duplicate'))}">${I('copy', 13)}</button><button class="bx-tool danger" data-act="fleetdel" data-i="${i}" title="${esc(t('gb_remove', null, 'Remove'))}">${I('remove', 13)}</button></div>
            <div class="bx-cardbody" style="padding-top:4px">
              <div class="bx-cols3">${field(t('gb_model', null, 'Model'), inp(`fleet.${i}.model`, { mono: true, list: 'gb-vehicles', max: 32 }))}${field(t('gb_label', null, 'Name'), inp(`fleet.${i}.label`, { max: 40 }))}${field(t('gb_min_grade', null, 'Lowest rank'), sel(`fleet.${i}.grade`, gopts, true))}</div>
              <div class="bx-cols3">${field(t('gb_mode', null, 'How'), sel(`fleet.${i}.mode`, [['borrow', t('gb_mode_borrow_l', null, 'Borrowed for the shift')], ['buy', t('gb_mode_buy_l', null, 'Bought, kept for the crew')]]))}${f.mode === 'buy' ? field(t('gb_price', null, 'Price'), unit(`fleet.${i}.price`, '$', { min: 0, step: 500 })) : field(t('gb_limit', null, 'Most out at once'), unit(`fleet.${i}.limit`, '', { min: 0, max: 100 }), t('gb_zero_any', null, '0 = no limit'))}${field(t('gb_plate', null, 'Plate starts with'), inp(`fleet.${i}.plate`, { mono: true, max: 4, placeholder: 'LSPD' }))}</div>
              <div class="bx-cols3">${field(t('gb_livery', null, 'Livery'), unit(`fleet.${i}.livery`, '', { min: -1, max: 80 }), t('gb_minus_none', null, '-1 = none'))}${field(t('gb_colours', null, 'Colours'), `<div style="display:flex;gap:6px">${unit(`fleet.${i}.color1`, '', { min: -1, max: 160 })}${unit(`fleet.${i}.color2`, '', { min: -1, max: 160 })}</div>`, t('gb_colours_hint', null, 'GTA colour numbers, -1 = stock'))}${field(t('gb_extras', null, 'Extras on'), `<input class="bx-input mono" data-extras="${i}" value="${esc(XS.list(f.extras).join(', '))}" placeholder="1, 2, 5">`, t('gb_extras_hint', null, 'The rest are switched off'))}</div>
              ${sw(`fleet.${i}.tuned`, t('gb_tuned', null, 'Fully tuned'), t('gb_tuned_hint', null, 'Engine, brakes, gearbox, suspension, armour and turbo maxed.'))}
            </div></div>`;
        return `<div class="bx-card" style="margin-bottom:14px"><div class="bx-cardbody"><div class="bx-hint" style="font-size:12.5px;line-height:1.55">${esc(t('gb_fleet_hint', null, 'Borrowed vehicles come out with a fresh plate and go back when parked at any of this group\'s garages, or when the driver logs out. Bought ones belong to the buyer and stay shared with the crew.'))}</div></div></div>
${d.fleet.map(row).join('')}
<button class="bx-btn" data-act="fleetadd">${I('plus', 15)}${esc(t('gb_fleet_add', null, 'Add a vehicle'))}</button>
<datalist id="gb-vehicles">${S.vehicles.map((v) => `<option value="${esc(v.model)}">${esc(v.label)}</option>`).join('')}</datalist>`;
    }

    function blipPicker() {
        const d = S.cur;
        const B = XS.BLIPS;
        if (!B) return '';
        const sprite = d.blip.sprite || 0;
        const colour = d.blip.colour;
        return `<div class="gb-blips">${B.sprites.map((sp) => `<button class="gb-sp ${Number(sprite) === sp.id ? 'on' : ''}" data-act="sprite" data-id="${sp.id}" title="${esc(sp.label)} · ${sp.id}"><img src="${esc(B.image(sp))}" alt="" loading="lazy" onerror="this.style.visibility='hidden'"></button>`).join('')}</div>
        <div class="gb-colours"><button class="gb-col ${colour < 0 ? 'on' : ''}" data-act="colour" data-id="-1" title="${esc(t('gb_default', null, 'Default'))}">A</button>${B.colours.slice(0, 40).map((c) => `<button class="gb-col ${Number(colour) === c.id ? 'on' : ''}" data-act="colour" data-id="${c.id}" title="${esc(c.label)} · ${c.id}" style="background:${c.hex}"></button>`).join('')}</div>`;
    }

    function tabLook() {
        const d = S.cur;
        const openName = (k) => t(`cfg_opt_${k}`, null, OPENS[k]);
        const openSetting = XS.BuilderSettings.value('General.openWith') === 'target' ? 'target' : 'key';
        const noAttendants = d.look.desk === 'ped' && XS.BuilderSettings.value('General.attendants') !== true;
        return `<div class="bx-layout"><div>
<div class="bx-card"><div class="bx-cardhead"><h3>${esc(t('gb_desk_look', null, 'At the desk'))}</h3></div><div class="bx-cardbody">
  ${field(t('gb_desk_what', null, 'What stands there'), sel('look.desk', LOOKS.map((l) => [l[0], t(`gb_look_${l[0]}`, null, l[1])])), noAttendants ? t('gb_attendants_off', null, 'Attendants are switched off in Settings, so a marker stands here for now.') : null)}
  ${field(t('gb_open_with', null, 'How players open it'), sel('look.open', [['', t('gb_open_setting', { mode: openName(openSetting) }, `Like the setting (${openName(openSetting)})`)], ['key', openName('key')], ['target', openName('target')]]))}
  ${d.look.desk === 'ped' ? `<div class="bx-cols2">${field(t('gb_ped', null, 'Attendant model'), inp('look.ped', { mono: true, max: 48, placeholder: 's_m_y_valet_01' }), t('gb_blank_setting', null, 'Empty uses the setting'))}${field(t('gb_scenario', null, 'What they do'), inp('look.scenario', { mono: true, max: 64, placeholder: 'WORLD_HUMAN_CLIPBOARD' }))}</div>` : ''}
  ${d.look.desk === 'prop' ? field(t('gb_prop', null, 'Prop model'), inp('look.prop', { mono: true, max: 48, placeholder: 'prop_parknmeter_01' }), t('gb_blank_setting', null, 'Empty uses the setting')) : ''}
</div></div></div><div>
<div class="bx-card"><div class="bx-cardhead"><h3>${esc(t('gb_mapicon', null, 'Map icon'))}</h3></div><div class="bx-cardbody">
  ${sw('blip.show', t('gb_blip_show', null, 'Show on the map'), d.type === 'job' || d.type === 'gang' ? t('gb_blip_group', null, 'Only members see it.') : (d.type === 'private' ? t('gb_blip_private', null, 'Owners and their people see it. Before it is taken, everyone can.') : null))}
  ${field(t('gb_label', null, 'Label'), inp('blip.label', { max: 40, placeholder: d.label }))}
  ${blipPicker()}
  <div class="bx-cols2">${field(t('gb_sprite', null, 'Icon number'), unit('blip.sprite', '', { min: 0, max: 900 }), t('gb_zero_type', null, '0 uses the type default'))}${field(t('gb_colour', null, 'Colour number'), unit('blip.colour', '', { min: -1, max: 85 }), t('gb_minus_type', null, '-1 uses the type default'))}</div>
</div></div></div></div>`;
    }

    function tabCars() {
        const key = S.cur.key;
        const list = S.cars.filter((c) => c.garage === key);
        return `<div class="bx-listbar"><span class="bx-hint">${esc(t('gb_cars_here', { n: list.length }, `${list.length} cars saved to this garage`))}</span><span class="bx-sp"></span><button class="bx-btn sm" data-act="carsload">${I('refresh', 14)}${esc(t('gb_refresh', null, 'Refresh'))}</button></div>${carTable(list, false)}`;
    }

    function editor() {
        const d = S.cur;
        if (!d) return overview();
        const tabs = ['general', 'points', 'access', 'money'];
        if (d.type === 'job' || d.type === 'gang') tabs.push('fleet');
        tabs.push('look');
        if (S.curId) tabs.push('cars');
        if (!tabs.includes(S.tab)) S.tab = 'general';
        const list = issues(d);
        const steps = [
            [t('gb_step_desk', null, 'Desk'), d.desks.length > 0, 'points'],
            [t('gb_step_spot', null, 'Parking spot'), d.type === 'impound' || d.drops.length > 0 || (d.display && d.spawns.length > 0), 'points'],
            [t('gb_step_bay', null, 'Bay'), d.spawns.length > 0, 'points'],
        ];
        if (d.type === 'job') steps.push([t('gb_step_job', null, 'Job'), !!d.job.name, 'access']);
        if (d.type === 'gang') steps.push([t('gb_step_gang', null, 'Gang'), !!d.gang.name, 'access']);
        const TAB = { general: ['info', 'General'], points: ['pin', 'Points'], access: ['shield', 'Who'], money: ['cash', 'Money'], fleet: ['car', 'Vehicle list'], look: ['eye', 'Look'], cars: ['parking', 'Cars'] };
        const counts = { points: d.desks.length + d.drops.length + d.spawns.length, fleet: d.fleet.length };
        const body = { general: tabGeneral, points: tabPoints, access: tabAccess, money: tabMoney, fleet: tabFleet, look: tabLook, cars: tabCars };
        const t0 = TYPES.find((x) => x.id === d.type) || TYPES[0];
        return `<div class="bx-crumb"><button data-act="nav" data-page="garages">${esc(t('gb_garages', null, 'Garages'))}</button>${I('chevron', 12)}<span>${esc(S.curId ? `#${S.curId}` : t('gb_new_short', null, 'New'))}</span></div>
<div class="bx-edhead"><input class="bx-edname" data-path="label" value="${esc(d.label)}" placeholder="${esc(t('gb_name_ph', null, 'Legion Square Parking'))}" maxlength="48"><span class="bx-sp"></span>
  ${S.curId ? `<button class="bx-btn ghost" data-act="tpg" data-id="${S.curId}">${I('goto', 15)}${esc(t('gb_teleport', null, 'Teleport'))}</button>${S.rights.delete ? `<button class="bx-btn danger" data-act="delete">${I('remove', 15)}</button>` : ''}` : ''}
  <button class="bx-btn primary" data-act="save" ${S.busy ? 'disabled' : ''}>${I('check', 15)}${esc(S.dirty || !S.curId ? t('gb_save', null, 'Save') : t('gb_saved', null, 'Saved'))}<span class="bx-kbd">Ctrl S</span></button></div>
<div class="bx-edmeta"><span class="bx-chip blue">${I(t0.icon, 12)}${esc(typeName(d.type))}</span><span class="bx-chip">${I(CAT_ICON[d.category] || 'car', 12)}${esc(catName(d.category))}</span>${d.standard ? `<span class="bx-chip">${esc(t('gb_from_standard', null, 'Standard'))}</span>` : ''}${d.enabled === false ? `<span class="bx-chip off">${esc(t('gb_switched_off', null, 'Switched off'))}</span>` : ''}${list.filter((i) => i.level === 'bad').length ? `<span class="bx-chip bad">${I('alert', 12)}${esc(t('gb_n_problems', { n: list.filter((i) => i.level === 'bad').length }, `${list.filter((i) => i.level === 'bad').length} to fix`))}</span>` : ''}</div>
<div class="bx-steps">${steps.map((s) => `<span class="bx-step ${s[1] ? 'done' : 'need'}" data-act="tab" data-tab="${s[2]}" style="cursor:pointer"><i>${I(s[1] ? 'check' : 'alert', 10)}</i>${esc(s[0])}</span>`).join('')}</div>
<div class="bx-tabs">${tabs.map((x) => `<button class="bx-tab ${S.tab === x ? 'on' : ''}" data-act="tab" data-tab="${x}">${I(TAB[x][0], 14)}${esc(t(`gb_tab_${x}`, null, TAB[x][1]))}${counts[x] ? `<em>${counts[x]}</em>` : ''}</button>`).join('')}</div>
${(body[S.tab] || tabGeneral)()}
<div style="height:60px"></div>`;
    }

    function standardPage() {
        const missing = S.standard.filter((s) => !s.added);
        return `${head(t('gb_standard', null, 'Standard garages'), t('gb_standard_sub', null, 'The usual GTA public garages, hangars, boathouses and impound lots, already placed. Add them, then change anything you like.'), missing.length ? `<button class="bx-btn primary" data-act="stdall">${I('plus', 15)}${esc(t('gb_add_missing', { n: missing.length }, `Add the ${missing.length} missing`))}</button>` : '')}
<div class="bx-card"><table class="bx-table"><thead><tr><th>${esc(t('gb_name', null, 'Name'))}</th><th>${esc(t('gb_type', null, 'Type'))}</th><th>${esc(t('gb_category', null, 'Vehicles'))}</th><th>${esc(t('gb_key', null, 'Garage key'))}</th><th class="r"></th></tr></thead><tbody>
${S.standard.map((s) => `<tr><td><b>${esc(s.label)}</b></td><td>${esc(typeName(s.type))}</td><td>${I(CAT_ICON[s.category] || 'car', 14)} ${esc(catName(s.category))}</td><td class="bx-mono bx-hint">${esc(s.id)}</td>
<td class="r">${s.added ? `<span class="bx-chip ok">${I('check', 12)}${esc(t('gb_added', null, 'Added'))}</span>` : `<button class="bx-btn xs" data-act="stdone" data-sid="${esc(s.id)}">${I('plus', 12)}${esc(t('gb_add', null, 'Add'))}</button>`}<button class="bx-tool" data-act="stdgo" data-sid="${esc(s.id)}" title="${esc(t('gb_teleport', null, 'Teleport'))}">${I('goto', 14)}</button></td></tr>`).join('')}
</tbody></table></div>
<div class="bx-hint" style="margin-top:10px">${esc(t('gb_standard_note', null, 'Their keys match qb-garages and qbx_garages, so cars parked there before keep showing up in the same place. Gang garages come switched off, as gang names differ per server.'))}</div>`;
    }

    function housesPage() {
        return `${head(t('gb_houses', null, 'House garages'), t('gb_houses_sub', null, 'Garages other scripts add, like XS-Housing. Edit them in that script. They show up here so you can see where cars are.'))}
${S.external.length ? `<div class="bx-card"><table class="bx-table"><thead><tr><th>${esc(t('gb_name', null, 'Name'))}</th><th>${esc(t('gb_key', null, 'Garage key'))}</th><th>${esc(t('gb_from', null, 'From'))}</th><th class="r">${esc(t('gb_spots_col', null, 'Spots'))}</th><th class="r">${esc(t('gb_parked_col', null, 'Parked'))}</th></tr></thead><tbody>
${S.external.map((e) => `<tr><td><b>${esc(e.label)}</b>${e.shared ? ` <span class="bx-chip">${esc(t('gb_shared_short', null, 'Shared'))}</span>` : ''}</td><td class="bx-mono bx-hint">${esc(e.key)}</td><td>${esc(e.resource)}</td><td class="r bx-mono">${e.spots}</td><td class="r bx-mono">${e.parked}</td></tr>`).join('')}
</tbody></table></div>` : `<div class="bx-empty">${I('home', 30)}<b>${esc(t('gb_no_houses', null, 'No house garages'))}</b><p>${esc(t('gb_no_houses_text', null, 'When XS-Housing runs, every house with a garage shows up here.'))}</p></div>`}`;
    }

    function statusChip(c) {
        const map = { parked: 'ok', out: 'warn', impound: 'bad', held: 'bad', lost: 'off' };
        return `<span class="bx-chip ${map[c.status] || ''}">${esc(t(`gb_cs_${c.status}`, null, c.status))}</span>`;
    }

    function carTable(list, withOwner) {
        if (!list.length) return `<div class="bx-empty">${I('car', 30)}<b>${esc(t('gb_no_cars', null, 'No cars'))}</b><p>${esc(t('gb_no_cars_text', null, 'Search by plate, owner name, citizen id or model.'))}</p></div>`;
        const opts = allKeys().map((k) => `<option value="${esc(k.key)}">${esc(k.label)}</option>`).join('');
        return `<div class="bx-card"><table class="bx-table"><thead><tr><th>${esc(t('gb_plate_col', null, 'Plate'))}</th><th>${esc(t('gb_car', null, 'Car'))}</th>${withOwner !== false ? `<th>${esc(t('gb_owner', null, 'Owner'))}</th>` : ''}<th>${esc(t('gb_status', null, 'Status'))}</th><th>${esc(t('gb_garage', null, 'Garage'))}</th><th class="r">${esc(t('gb_actions', null, 'Actions'))}</th></tr></thead><tbody>
${list.map((c) => `<tr><td class="bx-mono"><b>${esc(c.plate)}</b></td><td>${esc(c.nickname || c.label)}<div class="bx-hint">${esc(c.model)}</div></td>${withOwner !== false ? `<td>${esc(c.owner || '')}<div class="bx-hint bx-mono">${esc(c.cid || '')}</div></td>` : ''}
<td>${statusChip(c)}${c.depot ? `<div class="bx-hint">${esc(money(c.depot))}</div>` : ''}${c.hold && c.hold.reason ? `<div class="bx-hint">${esc(c.hold.reason)}</div>` : ''}</td><td>${esc(c.garageLabel || '—')}</td>
<td class="r" style="white-space:nowrap">${S.rights.vehicles ? `<select class="bx-input" data-carto="${esc(c.plate)}" style="width:150px;height:28px;display:inline-block"><option value="">${esc(t('gb_send_to', null, 'Send to garage…'))}</option>${opts}</select>
${c.status === 'out' ? `<button class="bx-tool" data-act="carwhere" data-plate="${esc(c.plate)}" title="${esc(t('gb_mark', null, 'Mark on my map'))}">${I('pin', 13)}</button>` : ''}
${c.status === 'impound' || c.status === 'held' ? `<button class="bx-tool" data-act="carrelease" data-plate="${esc(c.plate)}" title="${esc(t('gb_release', null, 'Release for free'))}">${I('unlock', 13)}</button>` : `<button class="bx-tool" data-act="carimpound" data-plate="${esc(c.plate)}" title="${esc(t('gb_impound_it', null, 'Impound'))}">${I('tow', 13)}</button>`}
${S.rights.removeCars ? `<button class="bx-tool danger" data-act="carremove" data-plate="${esc(c.plate)}" title="${esc(t('gb_remove_car', null, 'Delete the car for good'))}">${I('remove', 13)}</button>` : ''}` : ''}</td></tr>`).join('')}
</tbody></table></div>`;
    }

    function vehiclesPage() {
        return `${head(t('gb_vehicles', null, 'Vehicles'), t('gb_vehicles_sub', null, 'Find any owned car and see where it is. Send it to a garage, impound it or let it go.'))}
<div class="bx-listbar"><div class="bx-filter">${I('search', 15)}<input class="bx-input" id="gb-carq" value="${esc(S.carQ)}" placeholder="${esc(t('gb_car_search', null, 'Plate, owner name, citizen id or model, then Enter'))}"></div>
  <select class="bx-input" id="gb-cargarage" style="width:200px"><option value="">${esc(t('gb_any_garage', null, 'Any garage'))}</option>${allKeys().map((k) => `<option value="${esc(k.key)}" ${S.carGarage === k.key ? 'selected' : ''}>${esc(k.label)}</option>`).join('')}</select>
  ${STATUS.map((x) => `<button class="bx-btn xs ${S.carStatus === x ? 'primary' : 'ghost'}" data-act="carstatus" data-k="${x}">${esc(t(`gb_cs_${x}`, null, x[0].toUpperCase() + x.slice(1)))}</button>`).join('')}
  <span class="bx-sp"></span><button class="bx-btn sm" data-act="carsload">${I('search', 14)}${esc(t('gb_find', null, 'Find'))}</button></div>
${carTable(S.cars)}`;
    }

    function impoundPage() {
        return `${head(t('gb_impound', null, 'Impound'), t('gb_impound_sub', null, 'Every car waiting at an impound lot or held by the police, from XS-Garages, XS-PoliceSystem or anything else using the usual columns.'), `<button class="bx-btn sm" data-act="impload">${I('refresh', 14)}${esc(t('gb_refresh', null, 'Refresh'))}</button>`)}
${carTable(S.impounds)}`;
    }

    function logsPage() {
        return `${head(t('gb_logs', null, 'Logs'), t('gb_logs_sub', null, 'Parking, impounds, transfers, private garages and staff changes. Discord webhooks for each are in Settings › Builder.'))}
<div class="bx-listbar"><div class="bx-filter">${I('search', 15)}<input class="bx-input" id="gb-logq" value="${esc(S.logQ)}" placeholder="${esc(t('gb_log_search', null, 'Name, plate, citizen id or text'))}"></div>
  ${LOG_KINDS.map((k) => `<button class="bx-btn xs ${S.logKind === k ? 'primary' : 'ghost'}" data-act="logkind" data-k="${k}">${esc(t(`gb_log_${k}`, null, k[0].toUpperCase() + k.slice(1)))}</button>`).join('')}
  <span class="bx-sp"></span><button class="bx-btn sm" data-act="logload">${I('refresh', 14)}${esc(t('gb_refresh', null, 'Refresh'))}</button></div>
<div class="bx-card"><table class="bx-table"><thead><tr><th>${esc(t('gb_when', null, 'When'))}</th><th>${esc(t('gb_what', null, 'What'))}</th><th>${esc(t('gb_garage', null, 'Garage'))}</th><th>${esc(t('gb_plate_col', null, 'Plate'))}</th><th>${esc(t('gb_who', null, 'Who'))}</th><th>${esc(t('gb_detail', null, 'Detail'))}</th><th class="r">${esc(t('gb_amount', null, 'Amount'))}</th></tr></thead><tbody>
${S.logs.map((l) => { const k = allKeys().find((x) => x.key === l.garage); return `<tr><td class="bx-mono" style="white-space:nowrap">${esc(XS.date(l.at))}</td><td><span class="bx-chip">${esc(t(`log_kind_${l.kind}`, null, l.kind))}</span></td><td>${esc(k ? k.label : (l.garage || '—'))}</td><td class="bx-mono">${esc(l.plate || '')}</td><td>${esc(l.name || l.citizenid || '')}</td><td class="bx-hint">${esc(l.detail || '')}</td><td class="r bx-mono">${l.amount ? esc(money(l.amount)) : ''}</td></tr>`; }).join('') || `<tr><td colspan="7"><div class="bx-hint">${esc(t('gb_no_logs', null, 'Nothing yet.'))}</div></td></tr>`}
</tbody></table></div>`;
    }

    function accessPage() {
        const r = S.rights || {};
        const row = (k, label, hint) => `<div class="bx-rowline"><div><b>${esc(label)}</b>${hint ? `<div class="bx-hint">${esc(hint)}</div>` : ''}</div><span class="bx-chip ${r[k] ? 'ok' : 'off'}">${esc(r[k] ? t('gb_allowed', null, 'Allowed') : t('gb_not_allowed', null, 'Not allowed'))}</span></div>`;
        return `${head(t('gb_access', null, 'Access'), t('gb_access_sub', null, 'Who can open this builder, and what they can do in it.'))}
<div class="bx-layout"><div><div class="bx-card"><div class="bx-cardbody">
  <div class="gb-code">add_ace group.admin ${esc(S.ace)} allow</div>
  <div class="bx-hint" style="margin-top:8px">${esc(t('gb_access_how', { cmd: S.command }, `Add that line to server.cfg for every group that should build, then use /${S.command}. Config.Admin can also list licences and framework groups.`))}</div>
</div></div></div><div><div class="bx-card"><div class="bx-cardbody">
  ${row('delete', t('gb_r_delete', null, 'Delete garages'), t('gb_r_delete_hint', null, 'Cars inside move to the nearest public garage.'))}
  ${row('vehicles', t('gb_r_vehicles', null, 'Move, impound and release any car'))}
  ${row('removeCars', t('gb_r_remove', null, 'Delete cars for good'))}
  ${row('owners', t('gb_r_owners', null, 'Set private garage owners'))}
  <div class="bx-hint" style="margin-top:10px">${esc(t('gb_rights_where', null, 'Change these in config.lua under Config.Admin.rights.'))}</div>
</div></div></div></div>`;
    }

    function paletteItems() {
        const out = [];
        S.garages.forEach((g) => out.push({ group: t('gb_garages', null, 'Garages'), label: `#${g.id} ${g.data.label}`, sub: `${typeName(g.data.type)} · ${g.data.key}`, run: () => edit(g.id) }));
        [['overview', 'Overview'], ['garages', 'Garages'], ['standard', 'Standard garages'], ['houses', 'House garages'], ['vehicles', 'Vehicles'], ['impound', 'Impound'], ['logs', 'Logs'], ['settings', 'Settings'], ['access', 'Access']].forEach((x) => out.push({ group: t('gb_pages', null, 'Pages'), label: t(`gb_${x[0]}`, null, x[1]), run: () => go(x[0]) }));
        if (XS.BuilderSettings) XS.BuilderSettings.fields().forEach((f) => out.push({ group: t('gb_settings', null, 'Settings'), label: XS.BuilderSettings.label(f.key), sub: XS.BuilderSettings.sectionLabel(f.section), run: () => { go('settings'); setTimeout(() => XS.BuilderSettings.focus(f.key), 30); } }));
        return out;
    }

    function renderOverlay() {
        const ov = root.querySelector('#bx-ov');
        if (!ov) return;
        const o = S.overlay;
        if (!o) { ov.innerHTML = ''; return; }
        if (o.kind === 'palette') {
            const q = (o.q || '').trim().toLowerCase();
            const all = paletteItems();
            o.list = (q ? all.filter((i) => `${i.label} ${i.sub || ''}`.toLowerCase().includes(q)) : all.slice(0, 30)).slice(0, 60);
            o.idx = Math.min(o.idx || 0, Math.max(0, o.list.length - 1));
            let lastGroup = '';
            ov.innerHTML = `<div class="bx-overlay" data-act="ovclose"><div class="bx-palette" data-stop="1"><div class="bx-palin">${I('search', 17)}<input id="gb-palq" value="${esc(o.q || '')}" placeholder="${esc(t('gb_search', null, 'Search garages, settings and pages'))}" autocomplete="off"></div><div class="bx-palres xsp-scroll">${o.list.map((it, i) => { const g = it.group !== lastGroup ? `<div class="bx-palgroup">${esc(it.group)}</div>` : ''; lastGroup = it.group; return `${g}<button class="bx-palitem ${i === o.idx ? 'hl' : ''}" data-act="palrun" data-i="${i}"><b>${esc(it.label)}</b>${it.sub ? `<small>${esc(it.sub)}</small>` : ''}</button>`; }).join('') || `<div class="bx-empty" style="border:none">${esc(t('gb_nothing', null, 'Nothing matches'))}</div>`}</div><div class="bx-palfoot"><span class="bx-kbd">↑↓</span>${esc(t('gb_pal_move', null, 'move'))}<span class="bx-kbd">Enter</span>${esc(t('gb_pal_open', null, 'open'))}<span class="bx-kbd">Esc</span>${esc(t('gb_pal_close', null, 'close'))}</div></div></div>`;
            const input = ov.querySelector('#gb-palq');
            input.focus();
            input.setSelectionRange(input.value.length, input.value.length);
            return;
        }
        if (o.kind === 'modal') {
            ov.innerHTML = `<div class="bx-overlay" data-act="ovclose"><div class="bx-modal" data-stop="1"><h3>${esc(o.title)}</h3><p>${esc(o.text)}</p>${o.input ? `<input class="bx-input" id="gb-modalin" style="margin-top:12px" value="${esc(o.value || '')}" placeholder="${esc(o.placeholder || '')}" ${o.number ? 'type="number"' : ''}>` : ''}<div class="acts"><button class="bx-btn ghost" data-act="ovclose">${esc(t('gb_cancel', null, 'Cancel'))}</button><button class="bx-btn ${o.danger ? 'danger' : 'primary'}" data-act="modalok">${esc(o.ok || t('gb_ok', null, 'OK'))}</button></div></div></div>`;
            const i = ov.querySelector('#gb-modalin');
            if (i) i.focus();
        }
    }

    function modal(opts) {
        return new Promise((resolve) => {
            S.overlay = Object.assign({ kind: 'modal' }, opts, { resolve });
            renderOverlay();
        });
    }

    function closeOverlay(result) {
        const o = S.overlay;
        S.overlay = null;
        renderOverlay();
        if (o && o.resolve) o.resolve(result);
    }

    async function confirmLeave() {
        if (!S.dirty) return true;
        const ok = await modal({ title: t('gb_unsaved', null, 'Unsaved changes'), text: t('gb_unsaved_text', null, 'Leave without saving?'), ok: t('gb_leave', null, 'Leave'), danger: true });
        if (ok) S.dirty = false;
        return !!ok;
    }

    async function go(page) {
        if (S.page === 'edit' && page !== 'edit' && !(await confirmLeave())) return;
        S.page = page;
        if (page === 'logs' && !S.logs.length) loadLogs();
        if (page === 'impound') loadImpounds();
        render();
    }

    async function edit(id, tab) {
        if (S.page === 'edit' && S.curId !== id && !(await confirmLeave())) return;
        const g = byId(id);
        if (!g) return;
        S.cur = normalise(copy(g.data));
        S.curId = g.id;
        S.tab = tab || 'general';
        S.page = 'edit';
        S.dirty = false;
        S.ownerQ = '';
        S.ownerHits = [];
        render();
    }

    async function newGarage(type) {
        if (S.page === 'edit' && !(await confirmLeave())) return;
        S.cur = normalise(blank(type));
        if (type === 'impound') S.cur.look.desk = 'ped';
        S.curId = null;
        S.tab = 'general';
        S.page = 'edit';
        S.dirty = true;
        render();
    }

    function upsert(rec) {
        if (!rec) return;
        const i = S.garages.findIndex((g) => g.id === rec.id);
        if (i >= 0) S.garages[i] = rec; else S.garages.push(rec);
        S.garages.sort((a, b) => a.id - b.id);
    }

    async function refresh() {
        const res = await XS.rpc('b:refresh');
        if (res.ok) { apply(res.data, true); render(); }
    }

    async function save() {
        if (S.page === 'settings') return XS.BuilderSettings.save();
        if (S.page !== 'edit' || !S.cur || S.busy) return;
        const a = document.activeElement;
        if (a && a.blur) a.blur();
        if (!S.cur.label.trim()) return XS.toast(t('gb_need_name', null, 'Give it a name first.'), 'error');
        S.busy = true;
        const res = await XS.rpc('b:save', { id: S.curId, data: copy(S.cur) });
        S.busy = false;
        if (!res.ok) return XS.toast(res.error, 'error');
        upsert(res.data);
        S.curId = res.data.id;
        S.cur = normalise(copy(res.data.data));
        S.dirty = false;
        XS.toast(t('gb_saved_toast', null, 'Saved. It is live now.'), 'ok');
        refresh();
        render();
    }

    async function loadLogs() {
        const res = await XS.rpc('b:logs', { kind: S.logKind, q: S.logQ });
        if (res.ok) { S.logs = XS.list(res.data); if (S.page === 'logs') render(); }
    }

    async function loadCars() {
        const res = await XS.rpc('b:cars', { q: S.carQ, status: S.carStatus, garage: S.page === 'edit' && S.cur ? S.cur.key : S.carGarage });
        if (res.ok) { S.cars = XS.list(res.data); render(); } else XS.toast(res.error, 'error');
    }

    async function loadImpounds() {
        const res = await XS.rpc('b:impounds', {});
        if (res.ok) { S.impounds = XS.list(res.data); if (S.page === 'impound') render(); }
    }

    function changed(redraw) {
        S.dirty = true;
        if (redraw !== false) { S.keepScroll = true; render(); } else {
            const btn = root.querySelector('[data-act="save"]');
            if (btn) btn.innerHTML = `${I('check', 15)}${esc(t('gb_save', null, 'Save'))}<span class="bx-kbd">Ctrl S</span>`;
        }
    }

    async function place(kind, origin) {
        const existing = [].concat(S.cur.desks, S.cur.drops, S.cur.spawns);
        const res = await XS.rpc('b:place', { kind, category: S.cur.category, look: S.cur.look.desk, prop: S.cur.look.prop, origin, existing, label: t(`gb_pt_${kind}`, null, ({ desks: 'Desk', drops: 'Parking spot', spawns: 'Bay' })[kind]) });
        if (!res.ok) { if (res.error) XS.toast(res.error, 'error'); return null; }
        return res.data;
    }

    async function carAction(plate, action, payload) {
        const res = await XS.rpc('b:car', { plate, action, payload: payload || {} });
        if (!res.ok) return XS.toast(res.error, 'error');
        XS.toast(action === 'where' ? t('gb_marked', null, 'Marked on your map.') : t('gb_done', null, 'Done.'), 'ok');
        if (S.page === 'impound') loadImpounds(); else loadCars();
    }

    async function onClick(e) {
        const el = e.target.closest('[data-act],[data-ftype],[data-fcat]');
        if (!el) return;
        if (el.dataset.ftype) { S.fType = el.dataset.ftype; render(); return; }
        if (el.dataset.fcat) { S.fCat = el.dataset.fcat; render(); return; }
        if (el.classList.contains('bx-overlay') && e.target !== el) return;
        if (el.tagName === 'TR' && e.target.closest('input,select,textarea,button')) return;
        const act = el.dataset.act;
        const id = el.dataset.id ? Number(el.dataset.id) : null;
        if (el.tagName === 'INPUT' && act !== 'toggle') return;
        switch (act) {
            case 'close': if (await confirmLeave()) XS.close('builder'); break;
            case 'nav': go(el.dataset.page); break;
            case 'palette': S.overlay = { kind: 'palette', q: '', idx: 0 }; renderOverlay(); break;
            case 'palrun': { const it = S.overlay && S.overlay.list[Number(el.dataset.i)]; closeOverlay(); if (it) it.run(); break; }
            case 'ovclose': closeOverlay(false); break;
            case 'modalok': { const i = root.querySelector('#gb-modalin'); closeOverlay(i ? i.value : true); break; }
            case 'new': newGarage(el.dataset.type); break;
            case 'edit': edit(id, el.dataset.tab); break;
            case 'tab': S.tab = el.dataset.tab; if (S.tab === 'cars') loadCars(); render(); break;
            case 'save': save(); break;
            case 'tpg': { const g = byId(id); const p = g && (g.data.desks[0] || g.data.spawns[0]); if (p) XS.rpc('b:teleport', p); break; }
            case 'dup': {
                const g = byId(id);
                if (!g) break;
                if (S.page === 'edit' && !(await confirmLeave())) break;
                S.cur = normalise(copy(g.data));
                S.cur.label = `${S.cur.label} 2`;
                S.cur.key = '';
                S.cur.standard = '';
                S.curId = null;
                S.page = 'edit';
                S.tab = 'general';
                S.dirty = true;
                render();
                break;
            }
            case 'delete': {
                const ok = await modal({ title: t('gb_delete_title', null, 'Delete this garage?'), text: t('gb_delete_text', null, 'Cars parked here move to the nearest public garage. This cannot be undone.'), ok: t('gb_delete', null, 'Delete'), danger: true });
                if (!ok) break;
                const res = await XS.rpc('b:delete', { id: S.curId });
                if (!res.ok) { XS.toast(res.error, 'error'); break; }
                S.garages = S.garages.filter((g) => g.id !== S.curId);
                S.dirty = false;
                S.cur = null;
                S.curId = null;
                S.page = 'garages';
                XS.toast(res.data && res.data.movedTo ? t('gb_deleted_moved', { garage: res.data.movedTo }, `Deleted. Cars moved to ${res.data.movedTo}.`) : t('gb_deleted', null, 'Deleted.'), 'ok');
                refresh();
                break;
            }
            case 'toggle': setPath(S.cur, el.dataset.path, !getPath(S.cur, el.dataset.path)); changed(); break;
            case 'ptadd': case 'pthere': {
                const kind = el.dataset.kind;
                let p;
                if (act === 'ptadd') p = await place(kind);
                else {
                    const res = await XS.rpc('b:here');
                    if (res.ok) {
                        const h = res.data;
                        p = kind === 'spawns' ? { x: h.vx, y: h.vy, z: h.vz, w: h.vw } : { x: h.x, y: h.y, z: h.z, w: h.w };
                        if (kind === 'spawns' && !h.inVehicle) XS.toast(t('gb_not_in_car', null, 'Not in a car, so the bay is where you stand.'), 'info');
                    }
                }
                if (p) { S.cur[kind].push(p); changed(); }
                break;
            }
            case 'ptre': {
                const kind = el.dataset.kind;
                const i = Number(el.dataset.i);
                const p = await place(kind, S.cur[kind][i]);
                if (p) { S.cur[kind][i] = p; changed(); }
                break;
            }
            case 'ptdel': S.cur[el.dataset.kind].splice(Number(el.dataset.i), 1); changed(); break;
            case 'ptgo': { const p = S.cur[el.dataset.kind][Number(el.dataset.i)]; if (p) XS.rpc('b:teleport', p); break; }
            case 'dropsfromspawns': S.cur.drops = S.cur.spawns.map((p) => Object.assign({}, p)); changed(); break;
            case 'showpts': XS.rpc('b:showPoints', { garage: S.cur }); break;
            case 'fleetadd': S.cur.fleet.push({ model: '', label: '', grade: 0, livery: -1, extras: [], color1: -1, color2: -1, tuned: false, plate: '', mode: 'borrow', price: 0, limit: 0 }); changed(); break;
            case 'fleetdup': S.cur.fleet.splice(Number(el.dataset.i) + 1, 0, copy(S.cur.fleet[Number(el.dataset.i)])); changed(); break;
            case 'fleetdel': S.cur.fleet.splice(Number(el.dataset.i), 1); changed(); break;
            case 'sprite': S.cur.blip.sprite = Number(el.dataset.id); changed(); break;
            case 'colour': S.cur.blip.colour = Number(el.dataset.id); changed(); break;
            case 'stdall': case 'stdone': {
                const res = await XS.rpc('b:standard', { ids: act === 'stdall' ? 'all' : [el.dataset.sid] });
                if (!res.ok) { XS.toast(res.error, 'error'); break; }
                apply(res.data, true);
                XS.toast(t('gb_std_added', null, 'Added. They are live now.'), 'ok');
                render();
                break;
            }
            case 'stdgo': { const s = S.standard.find((x) => x.id === el.dataset.sid); if (s && s.desk) XS.rpc('b:teleport', s.desk); break; }
            case 'ownerclear': {
                const ok = await modal({ title: t('gb_evict_title', null, 'Take this garage back?'), text: t('gb_evict_text', null, 'The owner loses it with no refund. Cars inside move to the nearest public garage.'), ok: t('gb_evict', null, 'Take it back'), danger: true });
                if (!ok) break;
                const res = await XS.rpc('b:owner', { id: S.curId, action: 'clear' });
                if (!res.ok) { XS.toast(res.error, 'error'); break; }
                upsert(res.data);
                render();
                break;
            }
            case 'ownerset': {
                const res = await XS.rpc('b:owner', { id: S.curId, action: 'set', payload: { id: Number(el.dataset.pid), kind: el.dataset.kind } });
                if (!res.ok) { XS.toast(res.error, 'error'); break; }
                upsert(res.data);
                S.ownerHits = [];
                S.ownerQ = '';
                XS.toast(t('gb_owner_set', null, 'Owner set.'), 'ok');
                render();
                break;
            }
            case 'carsby': S.carStatus = el.dataset.status; S.page = 'vehicles'; render(); loadCars(); break;
            case 'carstatus': S.carStatus = el.dataset.k; loadCars(); break;
            case 'carsload': loadCars(); break;
            case 'impload': loadImpounds(); break;
            case 'carwhere': carAction(el.dataset.plate, 'where'); break;
            case 'carrelease': carAction(el.dataset.plate, 'release'); break;
            case 'carimpound': {
                const fee = await modal({ title: t('gb_impound_title', null, 'Impound this car'), text: t('gb_impound_text', null, 'What should the owner pay to get it back?'), input: true, number: true, value: '500', ok: t('gb_impound_it', null, 'Impound') });
                if (fee === false || fee === undefined || fee === null) break;
                carAction(el.dataset.plate, 'impound', { fee: Number(fee) || 0 });
                break;
            }
            case 'carremove': {
                const ok = await modal({ title: t('gb_remove_title', null, 'Delete this car for good?'), text: t('gb_remove_text', null, 'It is removed from player_vehicles. This cannot be undone.'), ok: t('gb_delete', null, 'Delete'), danger: true });
                if (ok) carAction(el.dataset.plate, 'remove');
                break;
            }
            case 'logkind': S.logKind = el.dataset.k; loadLogs(); render(); break;
            case 'logload': loadLogs(); break;
            default: break;
        }
    }

    let searchTimer = null;

    function keepFocus(sel, fn) {
        fn();
        render();
        const input = root.querySelector(sel);
        if (input) { input.focus(); input.setSelectionRange(input.value.length, input.value.length); }
    }

    function onInput(e) {
        const el = e.target;
        if (el.id === 'gb-palq') { S.overlay.q = el.value; S.overlay.idx = 0; renderOverlay(); return; }
        if (el.id === 'gb-q') return keepFocus('#gb-q', () => { S.q = el.value; });
        if (el.id === 'gb-logq') { S.logQ = el.value; return; }
        if (el.id === 'gb-carq') { S.carQ = el.value; return; }
        if (el.id === 'gb-ownerq') {
            S.ownerQ = el.value;
            clearTimeout(searchTimer);
            searchTimer = setTimeout(async () => {
                const res = await XS.rpc('b:players', { q: S.ownerQ });
                S.ownerHits = res.ok ? XS.list(res.data) : [];
                keepFocus('#gb-ownerq', () => {});
            }, 280);
            return;
        }
        if (el.dataset.extras !== undefined) {
            const i = Number(el.dataset.extras);
            S.cur.fleet[i].extras = el.value.split(/[\s,]+/).map((x) => parseInt(x, 10)).filter((n) => Number.isFinite(n) && n >= 0 && n <= 20);
            changed(false);
            return;
        }
        if (el.dataset.path && S.cur) {
            let v = el.value;
            if (el.dataset.num || el.type === 'number') v = el.value === '' ? 0 : Number(el.value);
            if (el.dataset.path === 'key') v = String(v).toLowerCase().replace(/[^a-z0-9_-]/g, '');
            setPath(S.cur, el.dataset.path, v);
            changed(false);
        }
    }

    function onChange(e) {
        const el = e.target;
        if (el.dataset.carto !== undefined) {
            if (el.value) carAction(el.dataset.carto, 'garage', { garage: el.value });
            return;
        }
        if (el.id === 'gb-cargarage') { S.carGarage = el.value; loadCars(); return; }
        if (el.id === 'gb-logq') { loadLogs(); return; }
        if (el.tagName === 'INPUT' && el.dataset.path && S.cur && S.page === 'edit') { S.keepScroll = true; render(); return; }
        if (el.tagName === 'SELECT' && el.dataset.path && S.cur) {
            let v = el.value;
            if (el.dataset.num) v = Number(v);
            setPath(S.cur, el.dataset.path, v);
            if (el.dataset.path === 'type' && v === 'impound') S.cur.display = false;
            changed();
        }
    }

    function onKey(e) {
        if (S.overlay && S.overlay.kind === 'palette') {
            const o = S.overlay;
            if (e.key === 'ArrowDown') { o.idx = Math.min((o.list || []).length - 1, (o.idx || 0) + 1); renderOverlay(); e.preventDefault(); return; }
            if (e.key === 'ArrowUp') { o.idx = Math.max(0, (o.idx || 0) - 1); renderOverlay(); e.preventDefault(); return; }
            if (e.key === 'Enter') { const it = (o.list || [])[o.idx || 0]; closeOverlay(); if (it) it.run(); e.preventDefault(); return; }
        }
        if (e.key === 'Enter' && S.overlay && S.overlay.kind === 'modal') { const i = root.querySelector('#gb-modalin'); closeOverlay(i ? i.value : true); e.preventDefault(); return; }
        if (e.key === 'Enter' && e.target.id === 'gb-logq') { loadLogs(); return; }
        if (e.key === 'Enter' && e.target.id === 'gb-carq') { loadCars(); return; }
        if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { S.overlay = { kind: 'palette', q: '', idx: 0 }; renderOverlay(); e.preventDefault(); return; }
        if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') { save(); e.preventDefault(); }
    }

    function apply(data, keepPage) {
        data = XS.fix(data || {});
        S.garages = XS.list(data.garages).map((g) => { g.data = normalise(g.data || {}); return g; });
        S.external = XS.list(data.external);
        S.standard = XS.list(data.standard);
        S.stats = data.stats || {};
        S.system = data.system || {};
        S.rights = data.rights || {};
        S.jobs = XS.list(data.jobs).map((j) => Object.assign(j, { grades: XS.list(j.grades) }));
        S.gangs = XS.list(data.gangs).map((j) => Object.assign(j, { grades: XS.list(j.grades) }));
        S.vehicles = XS.list(data.vehicles);
        S.me = data.me || {};
        S.ace = data.ace || S.ace;
        S.command = data.command || S.command;
        if (data.here) S.here = data.here;
        XS.BuilderSettings.load({ settings: data.settings || {}, jobs: S.jobs, items: [] });
        if (keepPage && S.page === 'edit' && S.curId && !S.dirty) {
            const g = byId(S.curId);
            if (g) S.cur = normalise(copy(g.data));
        }
        if (!keepPage) S.page = 'overview';
    }

    XS.apps.builder = {
        isOpen: () => S.open,
        escape() {
            if (S.overlay) return closeOverlay(false);
            confirmLeave().then((ok) => { if (ok) XS.close('builder'); });
        },
        on(action, data) {
            if (action === 'open') {
                apply(data, false);
                S.open = true;
                shell();
                XS.show('xsp-builder', true);
                render();
            } else if (action === 'reload') {
                apply(data, true);
                render();
            } else if (action === 'show') {
                S.open = true;
                XS.show('xsp-builder', true);
            } else if (action === 'hide') {
                XS.show('xsp-builder', false);
            } else if (action === 'close') {
                S.open = false;
                S.overlay = null;
                XS.show('xsp-builder', false);
            }
        },
    };

    root.addEventListener('click', onClick);
    root.addEventListener('input', onInput);
    root.addEventListener('change', onChange);
    window.addEventListener('keydown', (e) => { if (S.open && !root.classList.contains('xsp-hidden')) onKey(e); });
})();
