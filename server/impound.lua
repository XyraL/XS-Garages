Impound = {}

local function running(name)
    local state = GetResourceState(name)
    return state == 'started' or state == 'starting'
end

function Impound.Offered()
    local I = Config.Impound or {}
    if not I.enabled then return false end
    if running('XS-PoliceSystem') and not I.withPoliceSystem then return false end
    return true
end

function Impound.Role(src)
    local I = Config.Impound or {}
    local job = Framework.GetJob(src)
    if not job then return nil end
    if Util.IsPolice(job) then
        if I.duty ~= false and not job.onDuty then return nil end
        if (job.grade or 0) < (I.minGrade or 0) and not job.isBoss then return nil end
        return 'police'
    end
    if I.towJob and I.towJob ~= '' and job.name == I.towJob then
        if I.duty ~= false and not job.onDuty then return nil end
        return 'tow'
    end
    return nil
end

function Impound.Do(plate, opts)
    opts = opts or {}
    plate = Util.Plate(plate)
    local row = Vehicles.Row(plate)
    if not row then return false, 'not_owned' end
    local fee = math.max(0, math.floor(tonumber(opts.fee) or 0))
    local hours = math.max(0, tonumber(opts.hours) or 0)
    local now = os.time()
    local releaseAt = hours > 0 and (now + math.floor(hours * 3600)) or 0
    if hours > 0 then
        Vehicles.Update(plate, { state = 2, depotprice = 0 })
    else
        Vehicles.Update(plate, { state = 2, depotprice = math.max(1, fee) })
    end
    Vehicles.SetMeta(plate, { bay = 0 })
    if row.garage then Display.Clear(row.garage, plate) end
    MySQL.update.await('UPDATE xs_garages_impound SET done = 1 WHERE plate = ? AND done = 0', { plate })
    MySQL.insert.await('INSERT INTO xs_garages_impound (plate, citizenid, fee, release_at, reason, officer, officer_cid, at, released) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        plate, row.citizenid or '', fee, releaseAt, Util.Text(opts.reason or '', 200), Util.Text(opts.officer or '', 100), opts.officerCid or '', now, hours > 0 and 0 or 1,
    })
    local owner = Framework.SourceOf(row.citizenid)
    if owner then
        Framework.Notify(owner, hours > 0 and Text('impounded_held', { plate = plate, time = Util.Span(releaseAt - now) }) or Text('impounded_owner', { plate = plate, fee = Util.Money(fee) }), 'error')
    end
    return true, row
end

lib.callback.register('XS-Garages:server:impoundOptions', function(src)
    if not Impound.Offered() then return false, Text('err_off') end
    local role = Impound.Role(src)
    if not role then return false, Text('err_not_police') end
    local I = Config.Impound or {}
    return true, { fees = I.fees or { 500 }, holds = role == 'police' and (I.holds or { 0 }) or { 0 }, role = role }
end)

lib.callback.register('XS-Garages:server:impound', function(src, netId, opts)
    if not Impound.Offered() then return false, Text('err_off') end
    local role = Impound.Role(src)
    if not role then return false, Text('err_not_police') end
    opts = type(opts) == 'table' and opts or {}
    local veh = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return false, Text('err_no_vehicle') end
    if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(veh)) > 10.0 then return false, Text('err_too_far') end
    for seat = -1, 8 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped and ped ~= 0 then return false, Text('err_impound_occupied') end
    end
    local I = Config.Impound or {}
    local fee = tonumber(opts.fee) or 0
    if not Util.Has(I.fees or {}, fee) then fee = (I.fees or { 0 })[1] or 0 end
    local hours = tonumber(opts.hours) or 0
    if role ~= 'police' or not Util.Has(I.holds or {}, hours) then hours = 0 end
    local plate = Util.Plate(GetVehicleNumberPlateText(veh))
    local fleet = Fleet.Of(plate)
    if fleet then
        Fleet.out[plate:upper()] = nil
        Spawn.Remove(veh)
        return true, { plate = plate, owned = false }
    end
    local ok, row = Impound.Do(plate, { fee = fee, hours = hours, reason = opts.reason, officer = Framework.GetName(src), officerCid = Framework.GetCitizenId(src) })
    Spawn.Remove(veh)
    if ok then
        Logs.Add(hours > 0 and 'hold' or 'impound', '', plate, Logs.Who(src), Util.Text(opts.reason or '', 200) .. (hours > 0 and (' · ' .. Text('log_hold_hours', { n = hours })) or ''), fee)
    end
    return true, { plate = plate, owned = ok == true }
end)

local function releaseTick()
    local now = os.time()
    local rows = MySQL.query.await('SELECT * FROM xs_garages_impound WHERE done = 0 AND released = 0 AND release_at > 0 AND release_at <= ?', { now }) or {}
    for _, r in ipairs(rows) do
        local row = Vehicles.Row(r.plate)
        if row and tonumber(row.state) == 2 and (tonumber(row.depotprice) or 0) == 0 then
            Vehicles.Update(r.plate, { depotprice = math.max(1, tonumber(r.fee) or 0) })
            local owner = Framework.SourceOf(row.citizenid)
            if owner then Framework.Notify(owner, Text('hold_over', { plate = Util.Plate(r.plate) }), 'inform') end
        end
        MySQL.update.await('UPDATE xs_garages_impound SET released = 1 WHERE id = ?', { r.id })
    end
end

CreateThread(function()
    while not Garages.ready do Wait(1000) end
    while true do
        local ok, e = pcall(releaseTick)
        if not ok then print(('^1[XS-Garages]^0 impound check failed: %s'):format(tostring(e))) end
        Wait(60 * 1000)
    end
end)
