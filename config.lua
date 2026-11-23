Config = {}

-- Most of these can also be changed in game: /garagebuilder › Settings.
-- Changes made there are saved to the database and win over this file.

Config.Locale = 'en'
Config.Debug = false

Config.Bridges = {
    framework = 'auto',     -- auto, qbox, qbcore
    target = 'auto',        -- auto, ox_target, qb-target, sleepless_interact, interact, qtarget, none ([E] prompts)
    keys = 'auto',          -- auto, none, or the key script's resource name
    fuel = 'auto',          -- auto, none, or the fuel script's resource name
    banking = 'auto',       -- auto, none, or the banking script's resource name (for society accounts)
}

Config.Commands = {
    builder = 'garagebuilder',
    impound = 'impound',
    findCar = 'findcar',
}

-- Who can open the builder. Any one of these passing is enough.
-- Simplest: add this line to server.cfg
--   add_ace group.admin xs.garages.admin allow
Config.Admin = {
    acePermission = 'xs.garages.admin',
    groups = { 'admin', 'god' },
    licenses = {},
    rights = {
        delete = true,      -- delete garages
        vehicles = true,    -- move, release and send any player's car
        removeCars = false, -- delete a car from player_vehicles for good
        owners = true,      -- set or clear private garage owners
    },
}

Config.General = {
    openWith = 'key',       -- key: walk up and press E · target: your target script (E when there is none). Each garage can pick its own in the builder
    attendants = false,     -- true: desks set to an attendant get one standing there · false: they show a marker instead
    markers = true,         -- draw markers on desks and parking spots
    blips = true,
    warpIn = true,          -- sit the player in the driver seat when a car comes out
    fade = true,            -- quick fade while the car comes out
    lockOnSpawn = false,
    engineOff = true,       -- cars come out with the engine off
    deskPed = 's_m_y_valet_01',
    deskScenario = 'WORLD_HUMAN_CLIPBOARD',
    deskProp = 'prop_parknmeter_01',
    photos = 'https://docs.fivem.net/vehicles/%s.webp', -- car pictures in the garage screen, %s is the model name ('' = no pictures)
}

Config.Parking = {
    anywhere = false,       -- true: take any of your cars out at any public garage
    moveFee = 250,          -- when anywhere is false: fetch a car parked at another garage for this
    takeOutFee = 0,         -- every time a car comes out
    parkFee = 0,            -- every time a car is parked
    ownerOnly = false,      -- only the owner can park a car (otherwise anyone driving it)
    keysParkers = true,     -- with ownerOnly off, anyone with keys can park it
    passengersOut = true,   -- everyone has to get out before it is parked
    keepDamage = true,      -- cars come out as damaged as they went in
    keepFuel = true,
    minEngine = 0,          -- refuse to park a car with engine health below this (0 = never refuse)
    parkRadius = 6.0,       -- how close to a parking spot you have to stop
    clearRadius = 3.0,      -- a spawn bay counts as blocked if any car is this close
}

Config.Lost = {
    onRestart = 'garage',   -- garage, impound, keep: what happens to cars left out when the script starts
    whenRemoved = 'impound',-- impound, garage, keep: a car of ours was deleted from the world
    fee = 500,              -- what it costs to get a lost car back from an impound lot
    atGarage = false,       -- also let players get lost cars back at public garages
    garageFee = 1000,       -- the fee for that
    findCommand = true,     -- /findcar marks your out cars on the map
}

Config.Impound = {
    enabled = true,         -- police can impound cars (vehicle target + /impound)
    withPoliceSystem = false, -- also offer it when XS-PoliceSystem is running (it has its own)
    jobs = { 'police', 'sheriff', 'bcso', 'sasp' },
    types = { 'leo' },      -- or any job of these job types
    minGrade = 0,
    duty = true,
    fees = { 250, 500, 1000, 2500, 5000 },
    holds = { 0, 1, 6, 24, 72 }, -- hours the car is held before the owner can pay to get it back
    seconds = 6,            -- how long impounding takes
    society = 'police',     -- where impound fees go ('' = nowhere)
    towJob = 'tow',         -- this job can impound too, without holds ('' = no one)
}

Config.Transfer = {
    toPlayer = true,
    fee = 1000,
    nearby = true,          -- the other player has to be standing close
    range = 6.0,
}

Config.Share = {
    job = true,             -- players can leave their own car for their job to use
    gang = true,            -- ...or for their gang
}

Config.Private = {
    enabled = true,
    maxOwned = 2,
    maxAccess = 6,          -- people an owner can give access to
    sellBackPct = 60,
    rentDays = 7,
    autoPay = true,         -- rent comes out of the bank on its own
    graceDays = 2,          -- after that, the garage is taken back
}

Config.Fleet = {
    perPlayer = 1,          -- job cars one player can have out at once
    returnOnLogout = true,  -- a job car goes back when its driver logs out
    fullFuel = true,
}

Config.Mileage = {
    enabled = true,
    unit = 'mi',            -- mi or km
}

Config.Display = {
    enabled = true,         -- garages with "Show parked cars" switched on keep cars in their bays
    distance = 70.0,
}

Config.Spawn = {
    previewCar = 'sultan',  -- the ghost car while placing bays
    previewBoat = 'dinghy',
    previewAir = 'frogger',
}

Config.Builder = {
    showExisting = true,
    cameraSpeed = { normal = 6.0, fast = 18.0, slow = 1.5 },
    standardOnFirstStart = true, -- add the standard GTA garages the first time the script starts
}

Config.Blips = {
    public = { sprite = 357, colour = 3 },
    job = { sprite = 357, colour = 29 },
    gang = { sprite = 357, colour = 1 },
    private = { sprite = 357, colour = 46 },
    impound = { sprite = 68, colour = 47 },
    boat = { sprite = 356, colour = 3 },
    air = { sprite = 360, colour = 3 },
    onlyMine = true,        -- private garages only show for their owner and people with access
}

Config.Logs = {
    keepDays = 30,
    webhooks = {
        parking = '',
        impound = '',
        transfers = '',
        private = '',
        admin = '',
    },
}
