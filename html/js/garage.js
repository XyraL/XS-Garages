(() => {
    const root = document.getElementById('xsg-garage');
    const t = XS.t;
    const esc = XS.esc;
    const I = (n, s) => XS.icon(n, s || 16);
    const money = (n) => XS.money(n);
    const S = { open: false, data: null, tab: 'all', q: '', sel: null, modal: null, busy: false, intro: false, modalIntro: false, lastSide: null, lastTab: null };
    const photos = { ok: new Set(), bad: new Set() };

    const cars = () => XS.list(S.data && S.data.cars);
    const fleet = () => XS.list(S.data && S.data.fleet);
    const g = () => (S.data && S.data.garage) || {};
    const rules = () => (S.data && S.data.rules) || {};
    const priv = () => S.data && S.data.private;
    const me = () => (S.data && S.data.me) || {};
    const nameOf = (c) => c.nickname || c.label;
    const fits = (c) => c.fits !== false;
    const now = () => Math.floor(Date.now() / 1000);

    function kindIcon(cat) {
        if (cat === 'boat') return 'boat';
        if (cat === 'air') return 'helicopter';
        return 'car';
    }

    function photoSrc(model) {
        const pat = String(XS.config.photos || '');
        if (!pat || !model || !pat.includes('%s') || photos.bad.has(model)) return '';
        return pat.split('%s').join(encodeURIComponent(String(model).toLowerCase()));
    }

    function photo(model, cat, cls, size, extra) {
        const src = photoSrc(model);
        const ok = src && photos.ok.has(model);
        return `<div class="${cls}${ok ? ' gx-ok' : ''}">${src ? `<img src="${esc(src)}" data-model="${esc(model)}" alt="" draggable="false">` : ''}<span class="gx-ph">${I(kindIcon(cat), size)}</span>${extra || ''}</div>`;
    }

    function statusOf(c) {
        if (c.fleet) {
            if (c.locked) return { cls: 'lost', text: t('gx_rank', { n: c.grade }, `Rank ${c.grade}+`) };
            if (c.mode === 'buy') return { cls: 'fleet', text: money(c.price) };
            return { cls: 'here', text: t('gx_ready', null, 'Ready') };
        }
        if (c.status === 'parked') return c.here ? { cls: 'here', text: t('gx_st_here', null, 'Here') } : { cls: 'away', text: t('gx_st_away', null, 'Elsewhere') };
        return ({
            out: { cls: 'out', text: t('gx_st_out', null, 'Out') },
            impound: { cls: 'imp', text: t('gx_st_impound', null, 'Impounded') },
            held: { cls: 'held', text: t('gx_st_held', null, 'Held') },
            lost: { cls: 'lost', text: t('gx_st_lost', null, 'Missing') },
        })[c.status] || { cls: 'lost', text: c.status };
    }

    const pill = (st) => `<span class="gx-pill s-${st.cls}"><i></i><span>${esc(st.text)}</span></span>`;
    const plate = (p) => `<span class="gx-plate">${esc(p)}</span>`;
    const barColour = (p) => (p < 25 ? '#ff5463' : (p < 55 ? '#ffb02e' : '#2ed580'));
    const pct = (v) => Math.max(0, Math.min(100, Math.round(Number(v) || 0)));

    function distance(meters) {
        const unit = rules().unit === 'km' ? 'km' : 'mi';
        const v = unit === 'km' ? (Number(meters) || 0) / 1000 : (Number(meters) || 0) / 1609.344;
        return `${Math.floor(v).toLocaleString('en-US')} ${unit}`;
    }

    function tabList() {
        const d = g();
        const list = cars().filter(fits);
        const out = [];
        const p = priv();
        if (p && !p.access) return out;
        if (d.type === 'impound') {
            out.push({ id: 'all', label: t('gx_tab_impound', null, 'Impounded'), n: list.length });
        } else {
            out.push({ id: 'all', label: t('gx_tab_all', null, 'All'), n: list.length });
            out.push({ id: 'here', label: t('gx_tab_here', null, 'Here'), n: list.filter((c) => c.here).length });
            const away = list.filter((c) => c.status !== 'parked' || !c.here).length;
            if (away) out.push({ id: 'away', label: t('gx_tab_away', null, 'Elsewhere'), n: away });
            const crew = list.filter((c) => c.shared || !c.mine).length;
            if (crew) out.push({ id: 'crew', label: t('gx_tab_crew', null, 'Shared'), n: crew });
        }
        if (fleet().length) out.push({ id: 'fleet', label: t('gx_tab_fleet', null, 'Motor pool'), n: fleet().length });
        if (p && p.mine) out.push({ id: 'papers', label: t('gx_tab_papers', null, 'My garage'), n: null });
        return out;
    }

    function items() {
        if (S.tab === 'papers') return [];
        const q = S.q.trim().toLowerCase();
        if (S.tab === 'fleet') {
            return fleet().map((f) => Object.assign({ fleet: true, id: `fleet:${f.index}` }, f)).filter((f) => !q || `${f.label} ${f.model}`.toLowerCase().includes(q));
        }
        const list = cars().filter(fits).filter((c) => {
            if (S.tab === 'here' && !c.here) return false;
            if (S.tab === 'away' && c.status === 'parked' && c.here) return false;
            if (S.tab === 'crew' && !(c.shared || !c.mine)) return false;
            if (!q) return true;
            return `${c.plate} ${c.label} ${c.nickname} ${c.model} ${c.owner || ''}`.toLowerCase().includes(q);
        }).map((c, i) => Object.assign({ id: `car:${c.plate}`, order: i }, c));
        return list.sort((a, b) => (Number(!!b.favourite) - Number(!!a.favourite)) || (a.order - b.order));
    }

    function current() {
        return items().find((i) => i.id === S.sel) || null;
    }

    function lineOf(c) {
        if (c.status === 'parked' && c.here) return c.parkedAt ? t('gx_parked_ago', { time: XS.ago(c.parkedAt) }, `Parked ${XS.ago(c.parkedAt)}`) : t('gx_parked_here', null, 'Parked here');
        if (c.status === 'parked') return t('gx_at', { garage: c.garageLabel || '?' }, `At ${c.garageLabel || '?'}`);
        return where(c);
    }

    function row(c) {
        const sel = c.id === S.sel;
        const gone = !c.fleet && (c.status === 'out' || c.status === 'lost');
        const dim = c.fleet ? c.locked : (c.action === 'none' && !gone);
        const cat = c.fleet ? g().category : c.category;
        let sub;
        let mid;
        if (c.fleet) {
            sub = [c.mode === 'buy' ? t('gx_bought', null, 'Bought for the crew') : t('gx_borrowed', null, 'Borrowed for the shift'), c.tuned ? t('gx_tuned', null, 'Tuned') : null].filter(Boolean).join(' · ');
            mid = `<div class="gx-fuel">${esc(t('gx_out_n', { n: c.out }, `${c.out} out`))}</div>`;
        } else {
            sub = [c.nickname ? c.label : null, !c.mine && c.owner ? c.owner : null, c.sharedLabel ? t('gx_for', { crew: c.sharedLabel }, `For ${c.sharedLabel}`) : null].filter(Boolean).join(' · ') || lineOf(c);
            const f = pct(c.fuel);
            mid = c.status === 'parked' ? `<div class="gx-fuel" style="--bar:${barColour(f)}" title="${esc(t('gx_fuel', null, 'Fuel'))}">${I('drop', 12)}<i><u style="width:${f}%"></u></i>${f}%</div>` : '<div class="gx-fuel"></div>';
        }
        return `<div class="gx-row ${sel ? 'sel' : ''} ${dim ? 'dim' : ''}" data-pick="${esc(c.id)}">
            ${photo(c.model, cat, 'gx-thumb', 26)}
            <div class="gx-rname"><b>${c.favourite ? I('star', 14) : ''}<span>${esc(c.fleet ? c.label : nameOf(c))}</span></b><small>${esc(sub)}</small></div>
            ${mid}
            ${c.fleet ? '' : plate(c.plate)}
            ${pill(statusOf(c))}
        </div>`;
    }

    function why(c) {
        const w = c.why;
        if (!w) return '';
        if (w === 'held' && c.hold && c.hold.untilAt) {
            return t('gx_why_held_until', { time: XS.span(c.hold.untilAt - now()) }, `Held by the police for another ${XS.span(c.hold.untilAt - now())}.`);
        }
        if (w === 'impound') return t('gx_why_impound', { fee: money(c.depot || 0) }, `It is at the impound lot. Getting it back costs ${money(c.depot || 0)}.`);
        return t(`gx_why_${w}`, null, ({
            held: 'Held by the police.', lost: 'Nobody knows where it is. Get it back at an impound lot.', parked: 'It is parked in a garage, not here.',
            in_use: 'Someone in your crew has it out.', elsewhere: 'It is parked at another garage.', not_yours: 'This is not your car.', wrong_type: 'It does not fit here.',
        })[w] || 'You cannot take this one out here.');
    }

    function feeTag(fee) {
        const n = Number(fee) || 0;
        return `<small>${esc(n > 0 ? money(n) : t('gx_free', null, 'Free'))}</small>`;
    }

    function primary(c) {
        if (c.action === 'take') return `<button class="gx-go" data-act="take"><span>${esc(c.moving ? t('gx_bring', null, 'Bring it here') : t('gx_take', null, 'Take it out'))}</span>${feeTag(c.fee)}</button>`;
        if (c.action === 'release') return `<button class="gx-go red" data-act="take"><span>${esc(t('gx_release', null, 'Pay & release'))}</span>${feeTag(c.fee)}</button>`;
        if (c.action === 'recover') return `<button class="gx-go red" data-act="take"><span>${esc(t('gx_recover', null, 'Get it back'))}</span>${feeTag(c.fee)}</button>`;
        if (c.action === 'track') return `<button class="gx-go plain" data-act="track"><span>${esc(t('gx_track', null, 'Mark on map'))}</span><small>${I('pin')}</small></button>`;
        return `<button class="gx-go" disabled><span>${esc(t('gx_cannot', null, 'Not from here'))}</span><small>${I('lock')}</small></button>`;
    }

    function where(c) {
        if (c.status === 'parked') return c.garageLabel || t('gx_unknown', null, 'Unknown garage');
        return ({ out: t('gx_where_out', null, 'Out on the road'), impound: t('gx_where_impound', null, 'Impound lot'), held: t('gx_where_held', null, 'Police hold'), lost: t('gx_where_lost', null, 'Unknown') })[c.status] || c.status;
    }

    function carDetail(c) {
        const r = rules();
        const mini = [];
        if (c.mine) {
            if (c.canMove && c.action === 'take' && c.moving) mini.push(`<button class="wide" data-act="move">${I('swap')}${esc(t('gx_move', { fee: money(c.moveFee || 0) }, `Move it here for ${money(c.moveFee || 0)}`))}</button>`);
            mini.push(`<button data-act="rename">${I('edit')}${esc(t('gx_rename', null, 'Rename'))}</button>`);
            if (r.shareJob || r.shareGang) mini.push(`<button class="${c.shared ? 'on' : ''}" data-act="share">${I('people')}${esc(c.shared ? t('gx_shared', null, 'Shared') : t('gx_share', null, 'Share'))}</button>`);
            if (r.transfer && c.status === 'parked') mini.push(`<button data-act="give">${I('key')}${esc(t('gx_give', null, 'Give away'))}</button>`);
            if (c.status === 'out' && c.action !== 'track') mini.push(`<button data-act="track">${I('pin')}${esc(t('gx_track', null, 'Mark on map'))}</button>`);
        }
        const sub = [c.nickname ? c.label : null, !c.mine && c.owner ? t('gx_owned_by', { name: c.owner }, `Owned by ${c.owner}`) : null, c.sharedLabel ? t('gx_left_for', { crew: c.sharedLabel }, `Left for ${c.sharedLabel}`) : null].filter(Boolean).join(' · ');
        const held = c.hold && (c.status === 'held' || c.status === 'impound');
        let note = '';
        if (held) {
            const by = c.hold.officer ? t('gx_by', { name: c.hold.officer }, `By ${c.hold.officer}`) : '';
            const lead = c.action === 'none' ? why(c) : '';
            note = `<div class="gx-note">${I('alert')}<div>${lead ? `<b>${esc(lead)}</b><br>` : ''}${esc(c.hold.reason || t('gx_no_reason', null, 'No reason given.'))}${by ? `<small>${esc(by)}</small>` : ''}</div></div>`;
        } else if (c.action === 'none') note = `<div class="gx-note">${I('info')}<div>${esc(why(c))}</div></div>`;
        else if (c.moving) note = `<div class="gx-note info">${I('info')}<div>${esc(t('gx_moving_note', { garage: c.garageLabel || '?' }, `Parked at ${c.garageLabel || '?'}. Bringing it here costs the moving fee.`))}</div></div>`;
        const f = pct(c.fuel);
        const e = pct((c.engine || 0) / 10);
        const b = pct((c.body || 0) / 10);
        const star = c.mine ? `<button class="gx-star ${c.favourite ? 'on' : ''}" data-act="fav" title="${esc(c.favourite ? t('gx_unfav', null, 'Starred') : t('gx_fav', null, 'Star'))}">${I('star', 17)}</button>` : '';
        const st = statusOf(c);
        return `${photo(c.model, c.category, `gx-hero s-${st.cls}`, 64, pill(st) + star)}
            <div class="gx-detail"><div class="gx-dbody">
                <div class="gx-title">${esc(nameOf(c))}</div>
                ${sub ? `<div class="gx-sub">${esc(sub)}</div>` : ''}
                <div class="gx-info">
                    <div><span>${esc(t('gx_plate', null, 'Plate'))}</span><b class="gx-plate">${esc(c.plate)}</b></div>
                    <div><span>${esc(r.mileage ? t('gx_mileage', null, 'Mileage') : t('gx_parked', null, 'Parked'))}</span><b>${esc(r.mileage ? distance(c.mileage) : (c.status === 'parked' && c.parkedAt ? XS.ago(c.parkedAt) : '—'))}</b></div>
                    <div class="wide"><span>${esc(t('gx_where', null, 'Where'))}</span><b>${esc(where(c))}${r.mileage && c.status === 'parked' && c.parkedAt ? ` · ${esc(XS.ago(c.parkedAt))}` : ''}</b></div>
                </div>
                <div class="gx-bars">
                    <div class="gx-bar" style="--bar:${barColour(f)}"><span>${esc(t('gx_fuel', null, 'Fuel'))}</span><i><u style="width:${f}%"></u></i><em>${f}%</em></div>
                    <div class="gx-bar" style="--bar:${barColour(e)}"><span>${esc(t('gx_engine', null, 'Engine'))}</span><i><u style="width:${e}%"></u></i><em>${e}%</em></div>
                    <div class="gx-bar" style="--bar:${barColour(b)}"><span>${esc(t('gx_body', null, 'Body'))}</span><i><u style="width:${b}%"></u></i><em>${b}%</em></div>
                </div>
                ${note}
                </div><div class="gx-dfoot">${mini.length ? `<div class="gx-mini">${mini.join('')}</div>` : ''}
                ${primary(c)}</div>
            </div>`;
    }

    function fleetDetail(f) {
        const limit = f.limit > 0 ? `${f.out} / ${f.limit}` : String(f.out);
        let btn;
        if (f.locked) btn = `<button class="gx-go" disabled><span>${esc(t('gx_rank_needed', { n: f.grade }, `Rank ${f.grade} needed`))}</span><small>${I('lock')}</small></button>`;
        else if (f.mode === 'buy') btn = `<button class="gx-go" data-act="fleetbuy"><span>${esc(t('gx_buy_one', null, 'Buy one'))}</span>${feeTag(f.price)}</button>`;
        else btn = `<button class="gx-go" data-act="fleet"><span>${esc(t('gx_sign_out', null, 'Sign it out'))}</span>${feeTag(0)}</button>`;
        const st = statusOf(f);
        return `${photo(f.model, g().category, `gx-hero s-${st.cls}`, 64, pill(st))}
            <div class="gx-detail"><div class="gx-dbody">
                <div class="gx-title">${esc(f.label)}</div>
                ${f.tuned ? `<div class="gx-sub">${esc(t('gx_fully_tuned', null, 'Fully tuned'))}</div>` : ''}
                <div class="gx-info">
                    <div><span>${esc(t('gx_rank_col', null, 'Rank'))}</span><b>${esc(f.grade)}+</b></div>
                    <div><span>${esc(t('gx_out_now', null, 'Out now'))}</span><b>${esc(limit)}</b></div>
                    <div class="wide"><span>${esc(t('gx_type', null, 'Type'))}</span><b>${esc(f.mode === 'buy' ? t('gx_type_buy', null, 'Bought for the crew') : t('gx_type_borrow', null, 'Borrowed for the shift'))}</b></div>
                </div>
                <div class="gx-note info">${I('info')}<div>${esc(f.mode === 'buy' ? t('gx_how_buy', null, 'You pay once. It stays in this garage for everyone in the crew.') : t('gx_how_borrow', null, 'Yours for the shift. Park it at any of these garages to hand it back.'))}</div></div>
                </div><div class="gx-dfoot">${btn}</div>
            </div>`;
    }

    function initials(name) {
        return String(name || '?').split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0].toUpperCase()).join('') || '?';
    }

    function papersDetail() {
        const p = priv();
        const left = p.paidUntil ? Math.max(0, p.paidUntil - now()) : 0;
        const people = XS.list(p.people);
        const rented = p.kind === 'rented';
        return `<div class="gx-hero icon"><span class="gx-ph">${I('key', 60)}</span>${pill({ cls: 'here', text: rented ? t('gx_rented', null, 'Rented') : t('gx_owned', null, 'Owned') })}</div>
            <div class="gx-detail"><div class="gx-dbody">
                <div class="gx-title">${esc(g().label)}</div>
                <div class="gx-sub">${esc(p.owner || '')}</div>
                <div class="gx-info">
                    <div><span>${esc(t('gx_spaces', null, 'Spaces'))}</span><b>${esc(`${p.used} / ${p.slots}`)}</b></div>
                    <div><span>${esc(rented ? t('gx_paid_for', null, 'Paid for') : t('gx_since', null, 'Since'))}</span><b>${esc(rented ? XS.span(left) : XS.date(p.since).slice(0, 10))}</b></div>
                    ${rented ? `<div class="wide"><span>${esc(t('gx_rent', null, 'Rent'))}</span><b>${esc(t('gx_rent_every', { fee: money(p.rent), days: p.rentDays }, `${money(p.rent)} every ${p.rentDays} days`))}</b></div>` : ''}
                </div>
                <div class="gx-info" style="margin-top:18px"><div class="wide"><span>${esc(t('gx_access', { n: people.length, max: p.maxAccess }, `People with a key · ${people.length}/${p.maxAccess}`))}</span></div></div>
                <div class="gx-people">${people.map((a) => `<div class="gx-person"><i class="gx-av">${esc(initials(a.name || a.cid))}</i><span>${esc(a.name || a.cid)}</span><button data-act="unaccess" data-cid="${esc(a.cid)}">${esc(t('gx_remove', null, 'Remove'))}</button></div>`).join('') || `<div class="gx-none">${esc(t('gx_no_people', null, 'Only you can use it.'))}</div>`}</div>
                </div><div class="gx-dfoot"><div class="gx-mini">
                    ${people.length < p.maxAccess ? `<button class="${rented ? '' : 'wide'}" data-act="addaccess">${I('plus')}${esc(t('gx_add_person', null, 'Add someone'))}</button>` : ''}
                    ${rented ? `<button class="${people.length < p.maxAccess ? '' : 'wide'}" data-act="payrent">${I('cash')}${esc(t('gx_pay_rent', { fee: money(p.rent) }, `Pay ${money(p.rent)}`))}</button>` : ''}
                </div>
                <button class="gx-go soft" data-act="sell"><span>${esc(rented ? t('gx_stop_renting', null, 'Stop renting') : t('gx_sell', null, 'Sell it back'))}</span>${rented ? '' : feeTag(p.sellBack)}</button></div>
            </div>`;
    }

    function papersMain() {
        const p = priv();
        const here = cars().filter((c) => c.here);
        const slots = Math.max(Number(p.slots) || 0, here.length);
        const used = Math.min(100, Math.round((here.length / Math.max(1, slots)) * 100));
        let tiles = '';
        for (let i = 0; i < slots; i++) {
            const c = here[i];
            tiles += c
                ? `<div class="gx-slot" data-goto="${esc(c.plate)}" style="cursor:pointer"><span class="gx-slotnum">${String(i + 1).padStart(2, '0')}</span>${photo(c.model, c.category, 'gx-thumb', 24)}<b>${esc(nameOf(c))}</b><small>${plate(c.plate)}</small></div>`
                : `<div class="gx-slot free"><span class="gx-slotnum">${String(i + 1).padStart(2, '0')}</span>${I('parking', 22)}${esc(t('gx_free_space', null, 'Free space'))}</div>`;
        }
        return `<div class="gx-scroll"><div class="gx-overview"><div><b>${esc(t('gx_spaces_used', { n: here.length, max: slots }, `${here.length} of ${slots} spaces used`))}</b>
            <span>${esc(t('gx_papers_text', null, 'Who has a key and the payments are on the right. Click a car to see it.'))}</span><div class="gx-meter"><u style="width:${used}%"></u></div></div></div>
            <div class="gx-slots">${tiles}</div></div>`;
    }

    function leaseView() {
        const p = priv();
        const text = p.owned
            ? `<div class="gx-taken"><b>${esc(t('gx_taken_title', null, 'Already taken'))}</b>${esc(t('gx_taken_text', null, 'This garage belongs to someone else. Only they and the people they pick can get in.'))}</div>`
            : `<div class="gx-offers">
                ${p.buy ? `<div class="gx-offer main"><span>${esc(t('gx_to_buy', null, 'Buy'))}</span><b>${esc(money(p.price))}</b><p>${esc(t('gx_buy_text', { fee: money(p.sellBack || 0) }, 'Yours for good. You can sell it back later.'))}</p><button class="gx-go" data-act="buy"><span>${esc(t('gx_buy_it', null, 'Buy it'))}</span>${feeTag(p.price)}</button></div>` : ''}
                ${p.rentable ? `<div class="gx-offer"><span>${esc(t('gx_to_rent', null, 'Rent'))}</span><b>${esc(money(p.rent))}<small>${esc(t('gx_per_days', { days: p.rentDays }, `/ ${p.rentDays} days`))}</small></b><p>${esc(t('gx_rent_text', null, 'Comes out of your bank on its own. Stop whenever you want.'))}</p><button class="gx-go plain" data-act="rent"><span>${esc(t('gx_rent_it', null, 'Rent it'))}</span>${feeTag(p.rent)}</button></div>` : ''}
            </div>`;
        return `<div class="gx-lease">
            <div class="gx-lease-text"><div class="gx-logo">${I('key')}</div>
                <h2>${esc(p.owned ? t('gx_private', null, 'Private garage') : t('gx_for_lease', null, 'For lease'))}</h2>
                <p>${esc(t('gx_lease_text', null, 'Your own lock-up. Only you and the people you give a key to can park here.'))}</p>
                <div class="gx-feats"><div class="gx-feat">${I('parking')}<b>${esc(p.slots)}</b>${esc(t('gx_spaces_l', null, 'spaces'))}</div><div class="gx-feat">${I('people')}<b>${esc(p.maxAccess)}</b>${esc(t('gx_keys_l', null, 'extra keys'))}</div></div>
            </div>${text}</div>`;
    }

    function side() {
        if (S.tab === 'papers' && priv() && priv().mine) return papersDetail();
        const c = current();
        if (!c) return `<div class="gx-pick"><span class="gx-ico">${I('car', 26)}</span><b>${esc(t('gx_pick', null, 'Nothing picked'))}</b><span>${esc(t('gx_pick_text', null, 'Pick a car on the left to see it here.'))}</span></div>`;
        return c.fleet ? fleetDetail(c) : carDetail(c);
    }

    function main() {
        if (S.tab === 'papers') return papersMain();
        const list = items();
        if (!list.length) {
            const text = S.q ? t('gx_empty_search', null, 'Nothing matches that search.') : (g().type === 'impound' ? t('gx_empty_impound', null, 'None of your cars are here. Good driving.') : t('gx_empty', null, 'Park a car here and it shows up in this list.'));
            return `<div class="gx-empty"><span class="gx-ico">${I(S.q ? 'search' : 'parking', 26)}</span><b>${esc(S.q ? t('gx_empty_search_title', null, 'No results') : t('gx_empty_title', null, 'No cars here yet'))}</b><span>${esc(text)}</span></div>`;
        }
        return `<div class="gx-scroll" id="gx-scroll"><div class="gx-rows">${list.map(row).join('')}</div></div>`;
    }

    function modal() {
        const m = S.modal;
        if (!m) return '';
        const intro = S.modalIntro ? ' intro' : '';
        const cancel = `<button data-act="modalclose">${esc(t('gx_cancel', null, 'Cancel'))}</button>`;
        if (m.kind === 'rename') {
            return `<div class="gx-modal${intro}" data-act="modalclose"><div class="gx-box" data-stop="1"><h3>${esc(t('gx_rename_title', null, 'Name this car'))}</h3><p>${esc(t('gx_rename_text', null, 'Shows here and in the phone. Leave it empty to use the model name.'))}</p>
                <input id="gx-name" maxlength="24" value="${esc(m.value || '')}" placeholder="${esc(m.placeholder || '')}"><div class="gx-acts">${cancel}<button class="ok" data-act="renameok">${esc(t('gx_save', null, 'Save'))}</button></div></div></div>`;
        }
        if (m.kind === 'pick') {
            const list = XS.list(m.list);
            return `<div class="gx-modal${intro}" data-act="modalclose"><div class="gx-box" data-stop="1"><h3>${esc(m.title)}</h3><p>${esc(m.text)}</p>
                ${list.length ? `<div class="gx-choices">${list.map((o, i) => `<button class="gx-choice ${m.chosen === i ? 'on' : ''}" data-act="choose" data-i="${i}"><i></i><span>${esc(o.label)}</span>${o.sub ? `<small>${esc(o.sub)}</small>` : ''}</button>`).join('')}</div>` : `<p>${esc(m.empty || '')}</p>`}
                <div class="gx-acts">${cancel}${list.length ? `<button class="ok" data-act="pickok" ${m.chosen === undefined ? 'disabled' : ''}>${esc(m.ok || t('gx_ok', null, 'OK'))}</button>` : ''}</div></div></div>`;
        }
        if (m.kind === 'confirm') {
            return `<div class="gx-modal${intro}" data-act="modalclose"><div class="gx-box" data-stop="1"><h3>${esc(m.title)}</h3><p>${esc(m.text)}</p>
                <div class="gx-acts">${cancel}<button class="${m.danger ? 'danger' : 'ok'}" data-act="confirmok">${esc(m.ok || t('gx_ok', null, 'OK'))}</button></div></div></div>`;
        }
        return '';
    }

    function counts() {
        const list = cars().filter(fits);
        if (g().type === 'impound') return [[list.length, t('gx_c_cars', null, 'cars'), 'imp'], [list.filter((c) => c.action === 'release' || c.action === 'recover').length, t('gx_c_ready', null, 'ready'), 'here']];
        return [[list.filter((c) => c.here).length, t('gx_c_here', null, 'here'), 'here'], [list.filter((c) => c.status === 'out').length, t('gx_c_out', null, 'out'), 'out'], [list.length, t('gx_c_cars', null, 'cars'), '']];
    }

    function render() {
        if (!S.open || !S.data) return;
        const scroller = root.querySelector('#gx-scroll');
        const top = scroller ? scroller.scrollTop : 0;
        const tabs = tabList();
        if (tabs.length && !tabs.some((x) => x.id === S.tab)) S.tab = tabs[0].id;
        const list = items();
        if (S.tab !== 'papers' && (!S.sel || !list.some((i) => i.id === S.sel))) S.sel = list.length ? list[0].id : null;
        const d = g();
        const kind = ({ impound: t('gx_kind_impound', null, 'Impound lot'), job: t('gx_kind_job', null, 'Job garage'), gang: t('gx_kind_gang', null, 'Crew garage'), private: t('gx_kind_private', null, 'Private garage'), house: t('gx_kind_house', null, 'Home garage') })[d.type] || t('gx_kind_public', null, 'Public garage');
        const logo = d.type === 'impound' ? 'tow' : (d.category === 'boat' ? 'boat' : (d.category === 'air' ? 'helicopter' : 'parking'));
        const p = priv();
        const locked = p && !p.access;
        const m = me();
        const intro = S.intro ? ' intro' : '';
        const sideKey = S.tab === 'papers' ? 'papers' : S.sel;
        const swap = sideKey !== S.lastSide;
        S.lastSide = sideKey;
        const fresh = S.tab !== S.lastTab;
        S.lastTab = S.tab;
        root.innerHTML = `<div class="gx-veil${intro}"></div><div class="xsp-stage"><div class="gx${intro} ${S.busy ? 'gx-busy' : ''}">
            <header class="gx-head"><div class="gx-logo">${I(logo)}</div>
                <div class="gx-name"><small>XS-Garages · ${esc(kind)}</small><h1>${esc(d.label || '')}</h1></div>
                <div class="gx-stats">${locked ? '' : counts().map((x) => `<div class="gx-stat${x[2] ? ` s-${x[2]}` : ''}"><b>${esc(x[0])}</b><span>${esc(x[1])}</span></div>`).join('')}</div>
                <button class="gx-x" data-act="close" title="Esc">${I('close', 16)}</button></header>
            ${locked ? leaseView() : `<div class="gx-body">
                <section class="gx-main">
                    <div class="gx-tools"><div class="gx-tabs">${tabs.map((x) => `<button class="gx-tab ${S.tab === x.id ? 'on' : ''}" data-tab="${x.id}">${esc(x.label)}${x.n !== null && x.n !== undefined ? `<em>${x.n}</em>` : ''}</button>`).join('')}</div>
                        ${S.tab !== 'papers' ? `<label class="gx-search">${I('search', 15)}<input id="gx-q" value="${esc(S.q)}" placeholder="${esc(t('gx_search', null, 'Search plate, name or model'))}"></label>` : ''}</div>
                    <div class="gx-list${fresh ? ' fresh' : ''}">${main()}</div>
                </section>
                <aside class="gx-side${swap ? ' swap' : ''}" ${S.sel ? `data-for="${esc(S.sel)}"` : ''}>${side()}</aside>
            </div>`}
            <footer class="gx-foot">${locked || S.tab === 'papers' ? '' : `<span><kbd>↑</kbd><kbd>↓</kbd>${esc(t('gx_k_pick', null, 'Pick'))}</span><span><kbd>Enter</kbd>${esc(t('gx_k_take', null, 'Take out'))}</span>`}<span><kbd>Esc</kbd>${esc(t('gx_k_close', null, 'Close'))}</span>
                <span class="gx-money">${m.cash !== undefined ? `<span>${esc(t('gx_cash', null, 'Cash'))} <b>${esc(money(m.cash))}</b></span>` : ''}${m.bank !== undefined ? `<span>${esc(t('gx_bank', null, 'Bank'))} <b>${esc(money(m.bank))}</b></span>` : ''}</span></footer>
            ${modal()}
        </div></div>`;
        S.intro = false;
        S.modalIntro = false;
        const sc = root.querySelector('#gx-scroll');
        if (sc) sc.scrollTop = top;
        const n = root.querySelector('#gx-name');
        if (n && document.activeElement !== n) { n.focus(); n.setSelectionRange(n.value.length, n.value.length); }
    }

    function apply(data) {
        S.data = XS.fix(data || {});
        S.data.cars = XS.list(S.data.cars);
        S.data.fleet = XS.list(S.data.fleet);
        if (S.data.private) S.data.private.people = XS.list(S.data.private.people);
    }

    async function call(name, payload, after) {
        if (S.busy) return null;
        S.busy = true;
        render();
        const res = await XS.rpc(name, payload);
        S.busy = false;
        if (!res.ok) {
            XS.toast(res.error, 'error');
            render();
            return null;
        }
        if (after) after(res.data);
        render();
        return res;
    }

    function openModal(m) {
        S.modal = m;
        S.modalIntro = true;
        render();
    }

    function step(dy) {
        const list = items();
        if (!list.length) return;
        let i = list.findIndex((x) => x.id === S.sel);
        i = i < 0 ? 0 : Math.max(0, Math.min(list.length - 1, i + dy));
        S.sel = list[i].id;
        render();
        const el = root.querySelector('.gx-row.sel');
        if (el && el.scrollIntoView) el.scrollIntoView({ block: 'nearest' });
    }

    async function nearbyPick(title, text, ok, run) {
        const res = await XS.rpc('c:nearby', {});
        const list = res.ok ? XS.list(res.data).map((p) => ({ label: p.name, sub: `#${p.id}`, id: p.id })) : [];
        openModal({ kind: 'pick', title, text, ok, list, empty: t('gx_nobody', null, 'Nobody is close enough. They need to stand right next to you.'), run });
    }

    async function onClick(e) {
        const tabEl = e.target.closest('[data-tab]');
        if (tabEl) { S.tab = tabEl.dataset.tab; S.sel = null; render(); return; }
        const pick = e.target.closest('[data-pick]');
        if (pick && !S.modal) { S.sel = pick.dataset.pick; render(); return; }
        const go = e.target.closest('[data-goto]');
        if (go && !S.modal) { S.tab = 'here'; S.q = ''; S.sel = `car:${go.dataset.goto}`; render(); return; }
        const el = e.target.closest('[data-act]');
        if (!el) return;
        if (el.classList.contains('gx-modal') && e.target !== el) return;
        const c = current();
        switch (el.dataset.act) {
            case 'close': XS.close('garage'); break;
            case 'modalclose': S.modal = null; render(); break;
            case 'take': if (c && !c.fleet) call('c:take', { plate: c.plate }); break;
            case 'fleet': if (c && c.fleet) call('c:fleet', { index: c.index }); break;
            case 'fleetbuy': if (c && c.fleet) {
                openModal({ kind: 'confirm', title: t('gx_buy_title', { car: c.label }, `Buy a ${c.label}?`), text: t('gx_buy_fleet_text', { fee: money(c.price) }, `${money(c.price)} comes out of your bank. It stays in this garage for the whole crew.`), ok: t('gx_buy', null, 'Buy'), run: () => call('c:fleetBuy', { index: c.index }, apply) });
            } break;
            case 'track': if (c) call('c:track', { plate: c.plate, label: nameOf(c) }, () => XS.toast(t('gx_marked', null, 'Marked on your map.'), 'ok')); break;
            case 'move': if (c) call('c:move', { plate: c.plate }, apply); break;
            case 'fav': if (c) call('c:favourite', { plate: c.plate, on: !c.favourite }, () => { const car = cars().find((x) => x.plate === c.plate); if (car) car.favourite = !c.favourite; }); break;
            case 'rename': if (c) openModal({ kind: 'rename', value: c.nickname || '', placeholder: c.label }); break;
            case 'renameok': {
                const v = (root.querySelector('#gx-name') || {}).value || '';
                S.modal = null;
                if (c) call('c:rename', { plate: c.plate, name: v.trim() }, apply);
                else render();
                break;
            }
            case 'share': if (c) {
                const r = rules();
                const list = [];
                if (r.shareJob) list.push({ label: t('gx_share_job', { crew: r.jobLabel || '' }, `Leave it for ${r.jobLabel || 'my job'}`), kind: 'job' });
                if (r.shareGang) list.push({ label: t('gx_share_gang', { crew: r.gangLabel || '' }, `Leave it for ${r.gangLabel || 'my gang'}`), kind: 'gang' });
                list.push({ label: t('gx_share_none', null, 'Just me'), kind: '' });
                const chosen = list.findIndex((o) => (o.kind ? c.shared.indexOf(`${o.kind}:`) === 0 : !c.shared));
                openModal({ kind: 'pick', title: t('gx_share_title', null, 'Who can use this car?'), text: t('gx_share_text', null, 'Shared cars show up in your crew garage for everyone in it. It stays yours.'), list, chosen: chosen < 0 ? undefined : chosen, ok: t('gx_save', null, 'Save'), run: (o) => call('c:share', { plate: c.plate, kind: o.kind }, apply) });
            } break;
            case 'give': if (c) nearbyPick(t('gx_give_title', null, 'Give this car away'), t('gx_give_text', { fee: money(rules().transferFee || 0) }, `The paperwork costs ${money(rules().transferFee || 0)}. The other person owns it from then on.`), t('gx_give_ok', null, 'Hand over the keys'), (o) => {
                openModal({ kind: 'confirm', title: t('gx_give_sure', { name: o.label }, `Give it to ${o.label}?`), text: t('gx_give_sure_text', null, 'You cannot undo this.'), ok: t('gx_give_ok', null, 'Hand over the keys'), danger: true, run: () => call('c:give', { plate: c.plate, target: o.id }, apply) });
            }); break;
            case 'choose': if (S.modal) { S.modal.chosen = Number(el.dataset.i); render(); } break;
            case 'pickok': {
                const m = S.modal;
                const o = m && XS.list(m.list)[m.chosen];
                S.modal = null;
                render();
                if (o && m.run) m.run(o);
                break;
            }
            case 'confirmok': {
                const m = S.modal;
                S.modal = null;
                render();
                if (m && m.run) m.run();
                break;
            }
            case 'buy': {
                const p = priv();
                openModal({ kind: 'confirm', title: t('gx_buy_garage', null, 'Buy this garage?'), text: t('gx_buy_garage_text', { fee: money(p.price) }, `${money(p.price)} comes out of your bank.`), ok: t('gx_buy_it', null, 'Buy it'), run: () => call('c:privateBuy', {}, apply) });
                break;
            }
            case 'rent': {
                const p = priv();
                openModal({ kind: 'confirm', title: t('gx_rent_garage', null, 'Rent this garage?'), text: t('gx_rent_garage_text', { fee: money(p.rent), days: p.rentDays }, `${money(p.rent)} now, then every ${p.rentDays} days from your bank.`), ok: t('gx_rent_it', null, 'Rent it'), run: () => call('c:privateRent', {}, apply) });
                break;
            }
            case 'payrent': call('c:privatePay', {}, apply); break;
            case 'sell': {
                const p = priv();
                const rented = p.kind === 'rented';
                openModal({ kind: 'confirm', danger: true, title: rented ? t('gx_stop_title', null, 'Stop renting?') : t('gx_sell_title', null, 'Sell this garage?'),
                    text: rented ? t('gx_stop_text', null, 'Cars inside move to the nearest public garage.') : t('gx_sell_text', { fee: money(p.sellBack) }, `You get ${money(p.sellBack)} back. Cars inside move to the nearest public garage.`),
                    ok: rented ? t('gx_stop_renting', null, 'Stop renting') : t('gx_sell', null, 'Sell it back'), run: () => call('c:privateSell', {}) });
                break;
            }
            case 'addaccess': nearbyPick(t('gx_add_title', null, 'Who gets a key?'), t('gx_add_text', null, 'They can park and take out their own cars here.'), t('gx_add_ok', null, 'Give a key'), (o) => call('c:privateAccess', { action: 'add', target: o.id }, apply)); break;
            case 'unaccess': call('c:privateAccess', { action: 'remove', target: el.dataset.cid }, apply); break;
            default: break;
        }
    }

    function onInput(e) {
        if (e.target.id === 'gx-q') {
            S.q = e.target.value;
            S.sel = null;
            render();
            const i = root.querySelector('#gx-q');
            if (i) { i.focus(); i.setSelectionRange(i.value.length, i.value.length); }
        }
    }

    function onKey(e) {
        if (!S.open) return;
        if (S.modal) {
            if (e.key === 'Enter' && S.modal.kind === 'rename') { e.preventDefault(); const b = root.querySelector('[data-act="renameok"]'); if (b) b.click(); }
            return;
        }
        if (e.target && e.target.id === 'gx-q') {
            if (e.key === 'Enter' || e.key === 'ArrowDown') { e.target.blur(); e.preventDefault(); }
            return;
        }
        if (e.key === 'ArrowDown') { step(1); e.preventDefault(); }
        else if (e.key === 'ArrowUp') { step(-1); e.preventDefault(); }
        else if (e.key === 'Enter') {
            const btn = root.querySelector('.gx-side .gx-go:not([disabled])');
            if (btn) { btn.click(); e.preventDefault(); }
        }
    }

    function onPhoto(e, ok) {
        const img = e.target;
        if (!img || img.tagName !== 'IMG' || !img.dataset.model) return;
        const holder = img.parentElement;
        if (ok) {
            photos.ok.add(img.dataset.model);
            if (holder) holder.classList.add('gx-ok');
        } else {
            photos.bad.add(img.dataset.model);
            if (holder) holder.classList.remove('gx-ok');
            img.remove();
        }
    }

    XS.span = XS.span || function span(seconds) {
        const s = Math.max(0, Math.floor(Number(seconds) || 0));
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (d > 0) return `${d}d ${h}h`;
        if (h > 0) return `${h}h ${String(m).padStart(2, '0')}m`;
        return `${Math.max(1, m)}m`;
    };

    XS.apps.garage = {
        isOpen: () => S.open,
        escape() {
            if (S.modal) { S.modal = null; render(); return; }
            XS.close('garage');
        },
        on(action, data) {
            if (action === 'open') {
                apply(data);
                S.open = true;
                S.tab = 'all';
                if (S.data.private && S.data.private.mine && !S.data.cars.length) S.tab = 'papers';
                S.q = '';
                S.sel = null;
                S.modal = null;
                S.busy = false;
                S.intro = true;
                S.lastSide = null;
                S.lastTab = null;
                XS.show('xsg-garage', true);
                render();
            } else if (action === 'update') {
                apply(data);
                render();
            } else if (action === 'close') {
                S.open = false;
                S.modal = null;
                XS.show('xsg-garage', false);
                root.innerHTML = '';
            }
        },
    };

    root.addEventListener('click', onClick);
    root.addEventListener('input', onInput);
    root.addEventListener('load', (e) => onPhoto(e, true), true);
    root.addEventListener('error', (e) => onPhoto(e, false), true);
    window.addEventListener('keydown', onKey);
})();
