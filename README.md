<h1 align="center">XS-Garages</h1>

<p align="center">Garages for <strong>QBox</strong> and <strong>QBCore</strong>, all built in game: public garages, job and gang motor pools, private lock-ups and impound lots.</p>

---

XS-Garages is the whole garage system in one resource. Staff place every garage from an in-game builder, players park and take out their cars from a clean garage screen, and the police tow cars to the impound lot.

It uses the framework's own `player_vehicles` table, so cars from your dealership, phone and police scripts keep working.

## Features

- QBox and QBCore support
- In-game builder with an overview of what still needs doing, Ctrl+K search and every setting live, no restart
- The standard GTA garages, hangars, boathouses and impound lots come already placed, with the same names qb-garages and qbx_garages use, so parked cars stay where they were
- Public garages, job garages, gang garages, private garages and impound lots, each for cars, boats, aircraft or anything
- Place desks, parking spots and bays in game. Bays are placed with a ghost car, and F snaps one to a parked car
- Walk up and press E to open a garage, or use your target script. One setting for all, and each garage can pick its own
- A marker, a pay machine or an attendant at each desk, and a map icon picked from the real GTA icons
- A clean garage screen with a picture of every car, its plate, where it is, fuel, engine, body and mileage. Addon cars without a picture get an icon
- Cars keep their mods, damage and fuel when parked, and come out with your keys
- Parked cars can stay visible in their bays. Walk up to yours and take it out
- Take a car out where you parked it, or fetch it from another garage for a fee. Or let any public garage hand out any car
- Name your cars, star your favourites, and mark the ones out driving on the map with `/findcar`
- Give a car to someone standing next to you, or leave it for your job or gang to use
- Job and gang motor pools: vehicles by rank with liveries, extras, colours and full tuning, borrowed for the shift or bought for the crew
- Borrowed vehicles go back when parked or when the driver logs out
- Private garages players buy or rent, with spaces, keys for friends, rent that pays itself, and selling back
- Police impound from the vehicle target or `/impound`, with a fee, a hold time and a reason. Fees go to the police account
- Impound lots also hand back cars that went missing out on the road
- Cars left out at a server restart go back to their garage or to the impound lot, your call
- House garages from XS-Housing show up on their own
- Staff can find any car, see where it is, send it to a garage, impound it or let it go
- Logs for parking, impounds, transfers, private garages and staff changes, with Discord webhooks

## Requirements

- QBox or QBCore
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- OneSync (on by default)

Optional:

- A target script (ox_target or qb-target), only if you want garages opened with target. Press E works without one
- A key script and a fuel script. Both are found on their own

## Installation

1. Stop your old garage script. Two garage scripts fight over the same cars.
2. Put `XS-Garages` in your resources folder.
3. Add it to `server.cfg` after its dependencies:

   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure XS-Garages
   ```

4. Give your staff the builder:

   ```cfg
   add_ace group.admin xs.garages.admin allow
   ```

5. Restart the server. The tables make themselves, and the standard garages are added on the first start.
6. Join and type `/garagebuilder` to change them or add your own.

Gang garages are added switched off, because gang names differ per server. Pick the gang and switch them on in the builder.

## Commands

| Command | Who | What |
| --- | --- | --- |
| `/garagebuilder` | Staff | Opens the builder |
| `/impound` | Police and tow | Impounds the closest vehicle. The vehicle target does the same |
| `/findcar` | Everyone | Marks your cars that are out on the map |

## Works with

| | |
| --- | --- |
| Car keys | qbx_vehiclekeys, qb-vehiclekeys, Renewed-Vehiclekeys, wasabi_carlock, qs-vehiclekeys, mk_vehiclekeys, cd_garage, okokGarage, t1ger_keys, vehicles_keys |
| Fuel | ox_fuel, LegacyFuel, cdn-fuel, ps-fuel, lc_fuel, lj-fuel, qb-fuel, Renewed-Fuel, okokGasStation, ti_fuel, BigDaddy-Fuel, x-fuel, rcore_fuel, qs-fuelstations, ND_Fuel, melons_fuel |
| Banking | Renewed-Banking, qb-banking, okokBanking, tgg-banking, wasabi_banking, fd_banking, qb-management |
| Target | ox_target, qb-target, sleepless_interact, interact, qtarget |

XS-Housing adds a garage at every house that has one.

XS-PoliceSystem keeps its own impound. Its held cars show as held here, and once they are released they can be paid out at any impound lot.

XS-Phone's Garage app and valet read the same cars.

## Configuration

Everything is in `config.lua`, and almost all of it can also be changed in game from the builder's Settings page. Those changes are live for everyone and override `config.lua`.

Text is in `locales/en.lua`.

## Exports

Server:

```lua
exports['XS-Garages']:RegisterGarage(key, { label, vehicleType, accessPoints = { { coords, spawn } }, canAccess, shared })
exports['XS-Garages']:UnregisterGarage(key)
exports['XS-Garages']:RefreshGarages()
exports['XS-Garages']:GetGarages()
exports['XS-Garages']:GetVehicleStatus(plate)          -- { status, garage, garageLabel, depot }
exports['XS-Garages']:IsVehicleOut(plate)
exports['XS-Garages']:SetVehicleGarage(plate, garageKey)
exports['XS-Garages']:ImpoundVehicle(plate, fee, hours, reason)
exports['XS-Garages']:ReleaseVehicle(plate, garageKey)
exports['XS-Garages']:TrackVehicle(plate, vehicle, citizenid) -- a car another script spawned
```

Client:

```lua
exports['XS-Garages']:OpenGarage(garageKey)
```

`RegisterGarage` takes the same options as qbx_garages, so a script that already supports qbx_garages needs one line changed.

## Support

Join the [Discord](https://discord.gg/XRURAw4TM2) for help.

## License

See [LICENSE](LICENSE).
