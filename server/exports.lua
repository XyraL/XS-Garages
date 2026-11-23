exports('RegisterGarage', function(key, opts)
    while not Garages.ready do Wait(100) end
    return Garages.Register(key, opts, GetInvokingResource())
end)

exports('UnregisterGarage', function(key)
    return Garages.Unregister(tostring(key or ''))
end)

exports('RefreshGarages', function()
    Garages.Changed()
    return true
end)

exports('GetGarages', function()
    local out = {}
    for _, g in ipairs(Garages.All()) do
        out[#out + 1] = { key = g.data.key, label = g.data.label, type = g.data.type, category = g.data.category, enabled = g.data.enabled }
    end
    return out
end)

exports('GetVehicleStatus', function(plate)
    local row = Vehicles.Row(plate)
    if not row then return nil end
    local g = Garages.Get(row.garage)
    return { status = Vehicles.Status(row), garage = row.garage, garageLabel = g and g.data.label or nil, depot = tonumber(row.depotprice) or 0 }
end)

exports('IsVehicleOut', function(plate)
    return Spawn.Find(plate) ~= nil
end)

exports('SetVehicleGarage', function(plate, garageKey)
    local g = Garages.Get(garageKey)
    if not g or not Vehicles.Row(plate) then return false end
    local veh = Spawn.Find(plate)
    if veh then Spawn.Remove(veh) end
    Vehicles.Update(plate, { state = 1, garage = g.data.key, depotprice = 0 })
    Vehicles.SetMeta(plate, { bay = 0, parked_at = os.time() })
    return true
end)

exports('ImpoundVehicle', function(plate, fee, hours, reason)
    local veh = Spawn.Find(plate)
    local ok = Impound.Do(plate, { fee = fee, hours = hours, reason = reason, officer = GetInvokingResource() or '' })
    if veh then Spawn.Remove(veh) end
    return ok == true
end)

exports('ReleaseVehicle', function(plate, garageKey)
    local row = Vehicles.Row(plate)
    if not row then return false end
    local g = garageKey and Garages.Get(garageKey)
    Vehicles.Update(plate, { state = 1, depotprice = 0, garage = g and g.data.key or row.garage })
    MySQL.update.await('UPDATE xs_garages_impound SET done = 1 WHERE plate = ? AND done = 0', { Util.Plate(plate) })
    return true
end)

exports('TrackVehicle', function(plate, entity, citizenid)
    if not entity or not DoesEntityExist(entity) then return false end
    Spawn.Track(plate, entity, { cid = citizenid })
    Entity(entity).state:set('xsgPlate', Util.Plate(plate), true)
    return true
end)
