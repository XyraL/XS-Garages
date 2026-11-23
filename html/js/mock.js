(() => {
    if (typeof GetParentResourceName === 'function') return;
    if (location.hostname.toLowerCase() === RESOURCE.toLowerCase()) return;

    const send = (app, action, data) => window.dispatchEvent(new MessageEvent('message', { data: { app, action, data } }));
    const params = new URLSearchParams(location.search);
    const view = params.get('view') || 'garage';
    const scenario = params.get('scenario') || 'public';
    if (params.get('bg') !== 'none') document.documentElement.style.background = 'linear-gradient(160deg,#6f7a86 0%,#3d4650 45%,#1d2228 100%)';
    const now = Math.floor(Date.now() / 1000);
    const hash = (s) => { let h = 0; for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0; return h; };

    const car = (plate, model, label, extra) => Object.assign({
        plate, model, hash: hash(model), label, nickname: '', favourite: false, status: 'parked', garage: 'motelgarage', garageLabel: 'Motel Parking', here: true,
        fuel: 80, engine: 980, body: 960, mileage: 48210, parkedAt: now - 3 * 3600, mine: true, shared: '', category: 'car', fits: true, action: 'take', fee: 0,
    }, extra || {});

    const CARS = [
        car('XYR 001', 'comet2', 'Pfister Comet', { nickname: 'The Silver One', favourite: true, mileage: 128940, fuel: 62 }),
        car('VV 1997', 'sultan', 'Karin Sultan', { fuel: 34, engine: 610, body: 540, mileage: 210334 }),
        car('XYR 002', 'bati', 'Pegassi Bati 801', { status: 'out', here: false, action: 'track', garage: '', garageLabel: '' }),
        car('DRFT 88', 'futo', 'Karin Futo', { here: false, garage: 'pillboxgarage', garageLabel: 'Pillbox Garage Parking', action: 'take', fee: 250, moving: true, canMove: true, moveFee: 250 }),
        car('LS 4421', 'baller', 'Gallivanter Baller', { status: 'impound', here: false, action: 'none', why: 'impound', depot: 1000, hold: { reason: 'Parked on the Legion Square fountain', officer: 'Ofc. Delia Moss', fee: 1000, untilAt: 0 } }),
        car('XYR 777', 'elegy2', 'Annis Elegy RH8', { status: 'held', here: false, action: 'none', why: 'held', hold: { reason: 'Used in a robbery at Fleeca', officer: 'Sgt. Rafael Duarte', fee: 2500, untilAt: now + 5 * 3600 } }),
        car('MULE 12', 'mule', 'Maibatsu Mule', { shared: 'job:trucker', sharedLabel: 'Trucking Co.', fuel: 100 }),
        car('OLD 1', 'emperor', 'Albany Emperor', { status: 'lost', here: false, action: 'none', why: 'lost' }),
        car('XS 2024', 'xs_streetr', 'Street R', { fuel: 18, engine: 1000, body: 1000, mileage: 3120, parkedAt: now - 600 }),
        car('SEA 9', 'dinghy', 'Nagasaki Dinghy', { category: 'boat', fits: false }),
    ];

    const FLEET = [
        { index: 1, model: 'police', label: 'Police Cruiser', grade: 0, locked: false, mode: 'borrow', price: 0, out: 3, limit: 0, mine: 0 },
        { index: 2, model: 'police2', label: 'Buffalo Cruiser', grade: 1, locked: false, mode: 'borrow', price: 0, out: 1, limit: 6, mine: 0 },
        { index: 3, model: 'police3', label: 'Interceptor', grade: 2, locked: false, mode: 'borrow', price: 0, out: 0, limit: 4, mine: 0, tuned: true },
        { index: 4, model: 'fbi2', label: 'Unmarked Granger', grade: 4, locked: true, mode: 'borrow', price: 0, out: 0, limit: 2, mine: 0 },
        { index: 5, model: 'policeb', label: 'Police Bike', grade: 0, locked: false, mode: 'buy', price: 18000, out: 0, limit: 0, mine: 0 },
    ];

    const PRIVATE = { owned: false, mine: false, access: false, price: 85000, rent: 2200, buy: true, rentable: true, slots: 6, used: 0, rentDays: 7, sellBack: 51000, maxAccess: 6 };

    function garageData() {
        const base = {
            garage: { key: 'motelgarage', label: 'Motel Parking', type: 'public', category: 'car', display: false, personal: true, shared: true, fees: { takeOut: 0, park: 0, move: 250 }, spawns: 4 },
            me: { cid: 'XYR10001', name: 'Vincent Valentine', cash: 2400, bank: 184500, job: 'Police', gang: null },
            rules: { unit: 'mi', mileage: true, transfer: true, transferFee: 1000, nearby: true, shareJob: true, shareGang: false, jobLabel: 'Police', anywhere: false },
            cars: CARS, fleet: [],
        };
        if (scenario === 'impound') {
            base.garage = Object.assign({}, base.garage, { key: 'impoundlot', label: 'Impound Lot', type: 'impound' });
            base.cars = [
                Object.assign({}, CARS[4], { action: 'release', fee: 1000, why: null }),
                Object.assign({}, CARS[5]),
                Object.assign({}, CARS[7], { action: 'recover', fee: 500, why: null }),
            ];
        } else if (scenario === 'job') {
            base.garage = Object.assign({}, base.garage, { key: 'police', label: 'Mission Row Motor Pool', type: 'job' });
            base.fleet = FLEET;
            base.cars = [CARS[0], Object.assign({}, CARS[6], { shared: 'job:police', sharedLabel: 'Police', mine: false, owner: 'Delia Moss', here: true })];
        } else if (scenario === 'private-vacant') {
            base.garage = Object.assign({}, base.garage, { key: 'g31', label: 'Vinewood Lock-up 4', type: 'private' });
            base.private = PRIVATE;
            base.cars = [];
        } else if (scenario === 'private-owner') {
            base.garage = Object.assign({}, base.garage, { key: 'g31', label: 'Vinewood Lock-up 4', type: 'private' });
            base.private = Object.assign({}, PRIVATE, { owned: true, mine: true, access: true, kind: 'rented', owner: 'Vincent Valentine', paidUntil: now + 4 * 86400, since: now - 10 * 86400, used: 2, people: [{ cid: 'XYR10007', name: 'Rafael Duarte' }] });
            base.cars = CARS.slice(0, 3).map((c, i) => Object.assign({}, c, i === 2 ? {} : { garage: 'g31', garageLabel: 'Vinewood Lock-up 4' }));
        } else if (scenario === 'empty') {
            base.cars = [];
        }
        return base;
    }

    const G = (id, data, extra) => Object.assign({ id, parked: 0, data: Object.assign({
        key: '', label: '', type: 'public', category: 'car', enabled: true, desks: [], drops: [], spawns: [], dropRadius: 0, display: false,
        look: { desk: 'ped', ped: '', scenario: '', prop: '', open: '' }, blip: { show: true, sprite: 0, colour: -1, label: '' }, job: { name: '', grade: 0, duty: true }, gang: { name: '', grade: 0 },
        personal: true, shared: true, fleet: [], fees: { takeOut: -1, park: -1, move: -1 }, private: { price: 50000, rent: 1500, slots: 4, buy: true, rentable: true }, impound: { lost: true }, standard: '', notes: '',
    }, data) }, extra || {});
    const P = (x, y, z, w) => ({ x, y, z, w });

    function builderData() {
        return {
            garages: [
                G(1, { key: 'motelgarage', label: 'Motel Parking', standard: 'motelgarage', desks: [P(275.58, -344.74, 44.19, 70)], drops: [P(271.26, -342.32, 44.7, 159.97)], spawns: [P(271.26, -342.32, 44.7, 159.97)] }, { parked: 14 }),
                G(2, { key: 'legion', label: 'Legion Square Multistorey', display: true, desks: [P(215.1, -808.9, 30.0, 250)], drops: [P(222.4, -800.1, 30.6, 248)], spawns: [P(229.3, -805.0, 30.5, 156), P(232.1, -798.2, 30.5, 156), P(234.6, -791.5, 30.5, 156), P(237.1, -784.9, 30.5, 156)] }, { parked: 22 }),
                G(3, { key: 'police', label: 'Mission Row Motor Pool', type: 'job', standard: 'police', job: { name: 'police', grade: 0, duty: true }, desks: [P(454.6, -1017.4, 27.4, 0)], drops: [P(438.4, -1018.3, 27.7, 90)], spawns: [P(438.4, -1018.3, 27.7, 90)], fleet: [{ model: 'police', label: 'Police Cruiser', grade: 0, plate: 'LSPD' }, { model: 'police3', label: 'Interceptor', grade: 2, plate: 'LSPD', tuned: true, limit: 4 }] }, { parked: 5 }),
                G(4, { key: 'ballas', label: 'Ballas', type: 'gang', enabled: false, standard: 'ballas', gang: { name: 'ballas', grade: 0 }, desks: [P(98.5, -1954.49, 19.86, 0)], drops: [], spawns: [P(98.5, -1954.49, 20.75, 335.73)] }),
                G(5, { key: 'g5', label: 'Vinewood Lock-up 4', type: 'private', desks: [P(-60.2, 380.3, 111.4, 160)], drops: [P(-62.1, 374.0, 112.2, 160)], spawns: [P(-62.1, 374.0, 112.2, 160)], private: { price: 85000, rent: 2200, slots: 6, buy: true, rentable: true } }, { owner: { name: 'Vincent Valentine', cid: 'XYR10001', kind: 'rented', paidUntil: now + 4 * 86400, access: [{ cid: 'XYR10007', name: 'Rafael Duarte' }] } }),
                G(6, { key: 'impoundlot', label: 'Impound Lot', type: 'impound', standard: 'impoundlot', desks: [P(400.45, -1630.87, 28.31, 228.88)], spawns: [P(407.2, -1645.58, 29.31, 228.28)] }, { parked: 0 }),
                G(7, { key: 'g7', label: 'Paleto Hangar', category: 'air', desks: [], drops: [], spawns: [] }),
            ],
            external: [{ key: 'xsh_12', label: 'Mirror Park 12 garage', resource: 'XS-Housing', category: 'car', spots: 2, parked: 1, shared: true }],
            standard: [
                { id: 'motelgarage', label: 'Motel Parking', type: 'public', category: 'car', added: true, desk: P(275.58, -344.74, 44.19, 70) },
                { id: 'sapcounsel', label: 'San Andreas Parking', type: 'public', category: 'car', added: false, desk: P(-330.67, -781.12, 32.98, 40) },
                { id: 'pillboxgarage', label: 'Pillbox Garage Parking', type: 'public', category: 'car', added: false, desk: P(218.66, -804.08, 29.77, 65) },
                { id: 'intairport', label: 'Airport Hangar', type: 'public', category: 'air', added: false, desk: P(-1025.34, -3017.0, 12.97, 331) },
                { id: 'lsymc', label: 'LSYMC Boathouse', type: 'public', category: 'boat', added: false, desk: P(-794.64, -1510.89, 0.62, 201) },
                { id: 'police', label: 'Police', type: 'job', category: 'car', added: true, desk: P(454.6, -1017.4, 27.42, 0) },
                { id: 'impoundlot', label: 'Impound Lot', type: 'impound', category: 'car', added: true, desk: P(400.45, -1630.87, 28.31, 228) },
            ],
            stats: { garages: 7, byType: { public: 3, job: 1, gang: 1, private: 1, impound: 1 }, parked: 41, out: 9, impound: 3, held: 1, lost: 2, privateOwned: 1, fleetOut: 4, cars: 56, weekFees: 18450 },
            system: { framework: 'qbox', target: 'ox_target', keys: 'qbx_vehiclekeys', banking: 'Renewed-Banking', housing: 'XS-Housing', police: 'XS-PoliceSystem', phone: 'XS-Phone', oldGarage: null },
            rights: { delete: true, vehicles: true, removeCars: false, owners: true },
            jobs: [{ name: 'police', label: 'Police', grades: [{ grade: 0, label: 'Recruit' }, { grade: 1, label: 'Officer' }, { grade: 2, label: 'Sergeant' }, { grade: 3, label: 'Lieutenant' }, { grade: 4, label: 'Chief' }] }, { name: 'ambulance', label: 'EMS', grades: [{ grade: 0, label: 'Trainee' }] }],
            gangs: [{ name: 'ballas', label: 'Ballas', grades: [{ grade: 0, label: 'Recruit' }, { grade: 3, label: 'Boss' }] }],
            vehicles: [{ model: 'police', label: 'Vapid Police Cruiser' }, { model: 'police2', label: 'Bravado Buffalo Cruiser' }, { model: 'police3', label: 'Vapid Interceptor' }, { model: 'sultan', label: 'Karin Sultan' }],
            settings: { sections: [
                { id: 'parking', icon: 'parking', fields: [{ key: 'Parking.anywhere', type: 'bool', section: 'parking' }, { key: 'Parking.moveFee', type: 'int', min: 0, max: 1000000, step: 50, unit: '$', section: 'parking' }, { key: 'Parking.keepDamage', type: 'bool', section: 'parking' }] },
                { id: 'impound', icon: 'tow', fields: [{ key: 'Impound.enabled', type: 'bool', section: 'impound' }, { key: 'Impound.fees', type: 'nums', min: 0, max: 1000000, count: 8, unit: '$', needs: 'Impound.enabled', section: 'impound' }] },
            ], values: { 'Parking.anywhere': false, 'Parking.moveFee': 250, 'Parking.keepDamage': true, 'Impound.enabled': true, 'Impound.fees': [250, 500, 1000] }, defaults: { 'Parking.anywhere': false, 'Parking.moveFee': 250, 'Parking.keepDamage': true, 'Impound.enabled': true, 'Impound.fees': [250, 500, 1000] }, boot: {} },
            me: { name: 'XyraL' }, ace: 'xs.garages.admin', command: 'garagebuilder',
            here: { x: 215.1, y: -808.9, z: 29.7, w: 250, vx: 229.3, vy: -805.0, vz: 30.5, vw: 156, inVehicle: true },
        };
    }

    const MOCK_CARS = CARS.map((c, i) => Object.assign({}, c, { owner: ['Vincent Valentine', 'Delia Moss', 'Rafael Duarte'][i % 3], cid: `XYR1000${(i % 3) + 1}` }));

    const reply = (data) => ({ ok: true, data });
    const RPC = {
        'c:take': () => { setTimeout(() => send('garage', 'close', {}), 300); return reply(true); },
        'c:fleet': () => { setTimeout(() => send('garage', 'close', {}), 300); return reply(true); },
        'c:fleetBuy': () => reply(garageData()),
        'c:move': () => reply(garageData()),
        'c:rename': () => reply(garageData()),
        'c:favourite': () => reply(true),
        'c:share': () => reply(garageData()),
        'c:nearby': () => reply([{ id: 4, name: 'Rafael Duarte' }, { id: 9, name: 'Delia Moss' }]),
        'c:give': () => reply(garageData()),
        'c:track': () => reply(true),
        'c:privateBuy': () => reply(Object.assign(garageData(), { private: Object.assign({}, PRIVATE, { owned: true, mine: true, access: true, kind: 'owned', owner: 'Vincent Valentine', since: now, people: [] }) })),
        'c:privateRent': () => reply(Object.assign(garageData(), { private: Object.assign({}, PRIVATE, { owned: true, mine: true, access: true, kind: 'rented', owner: 'Vincent Valentine', paidUntil: now + 7 * 86400, people: [] }) })),
        'c:privatePay': () => reply(garageData()),
        'c:privateAccess': () => reply(garageData()),
        'c:privateSell': () => { setTimeout(() => send('garage', 'close', {}), 300); return reply(true); },
        'b:refresh': () => reply(builderData()),
        'b:here': () => reply(builderData().here),
        'b:place': () => reply({ x: 231.4, y: -802.2, z: 30.5, w: 156 }),
        'b:save': (p) => reply({ id: p.id || 99, parked: 0, data: Object.assign({}, p.data, { key: p.data.key || 'g99' }) }),
        'b:delete': () => reply({ movedTo: 'Motel Parking' }),
        'b:standard': () => { const d = builderData(); d.standard.forEach((s) => { s.added = true; }); return reply(d); },
        'b:cars': (p) => reply(MOCK_CARS.filter((c) => !p.status || p.status === 'all' || c.status === p.status).filter((c) => !p.garage || c.garage === p.garage)),
        'b:impounds': () => reply(MOCK_CARS.filter((c) => c.status === 'impound' || c.status === 'held')),
        'b:car': () => reply(true),
        'b:owner': (p) => reply(G(5, builderData().garages[4].data, p.action === 'clear' ? {} : { owner: { name: 'Rafael Duarte', cid: 'XYR10007', kind: 'owned', paidUntil: 0, access: [] } })),
        'b:players': () => reply([{ id: 4, name: 'Rafael Duarte', cid: 'XYR10007' }, { id: 9, name: 'Delia Moss', cid: 'XYR10008' }]),
        'b:logs': () => reply([
            { id: 1, garage: 'motelgarage', kind: 'park', plate: 'XYR 001', name: 'Vincent Valentine', citizenid: 'XYR10001', detail: '', amount: 0, at: now - 600 },
            { id: 2, garage: '', kind: 'hold', plate: 'XYR 777', name: 'Rafael Duarte', citizenid: 'XYR10007', detail: 'Used in a robbery at Fleeca · held 6h', amount: 2500, at: now - 3600 },
            { id: 3, garage: 'impoundlot', kind: 'release', plate: 'LS 4420', name: 'Delia Moss', citizenid: 'XYR10008', detail: 'Paid and released', amount: 500, at: now - 7200 },
        ]),
        'b:settings': (p) => reply({ values: Object.assign({}, builderData().settings.values, p.changes), boot: {} }),
        'b:teleport': () => reply(true),
        'b:showPoints': () => reply(true),
    };

    XS.post = async (endpoint, payload) => {
        if (endpoint === 'close') { send(payload.app, 'close', {}); return { ok: true }; }
        if (endpoint !== 'rpc') return { ok: true };
        const fn = RPC[payload.name];
        await new Promise((r) => setTimeout(r, 60));
        return fn ? fn(payload.payload || {}) : { ok: true, data: null };
    };

    window.XSG_MOCK = { garageData, builderData, send };

    window.addEventListener('load', () => {
        send('core', 'boot', { locale: window.XSG_LOCALE || {}, config: { unit: 'mi', mileage: true, photos: params.get('photos') === 'off' ? '' : 'https://docs.fivem.net/vehicles/%s.webp' } });
        if (view === 'builder') {
            send('builder', 'open', builderData());
            const page = params.get('page');
            const edit = params.get('edit');
            setTimeout(() => {
                if (edit) {
                    const b = document.querySelector('[data-act="nav"][data-page="garages"]');
                    if (b) b.click();
                    setTimeout(() => {
                        const r = document.querySelector(`tr[data-act="edit"][data-id="${edit}"]`);
                        if (r) r.click();
                        const tab = params.get('tab');
                        if (tab) setTimeout(() => { const x = document.querySelector(`[data-act="tab"][data-tab="${tab}"]`); if (x) x.click(); }, 60);
                    }, 60);
                } else if (page) {
                    const b = document.querySelector(`[data-act="nav"][data-page="${page}"]`);
                    if (b) b.click();
                }
            }, 80);
        } else {
            send('garage', 'open', garageData());
            const tab = params.get('tab');
            if (tab) setTimeout(() => { const b = document.querySelector(`[data-tab="${tab}"]`); if (b) b.click(); }, 80);
        }
    });
})();
