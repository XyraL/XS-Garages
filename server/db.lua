Db = { ready = false, columns = {} }

local TABLES = {
    [[CREATE TABLE IF NOT EXISTS `xs_garages` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `data` LONGTEXT NOT NULL,
        `created_at` INT NOT NULL DEFAULT 0,
        `updated_at` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `xs_garages_vehicles` (
        `plate` VARCHAR(16) NOT NULL,
        `nickname` VARCHAR(40) NOT NULL DEFAULT '',
        `favourite` TINYINT NOT NULL DEFAULT 0,
        `mileage` DOUBLE NOT NULL DEFAULT 0,
        `category` VARCHAR(8) NOT NULL DEFAULT '',
        `shared` VARCHAR(64) NOT NULL DEFAULT '',
        `bay` INT NOT NULL DEFAULT 0,
        `parked_at` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`plate`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `xs_garages_owners` (
        `garage_id` INT NOT NULL,
        `citizenid` VARCHAR(64) NOT NULL,
        `name` VARCHAR(100) NOT NULL DEFAULT '',
        `kind` VARCHAR(12) NOT NULL DEFAULT 'owned',
        `price` INT NOT NULL DEFAULT 0,
        `since` INT NOT NULL DEFAULT 0,
        `paid_until` INT NOT NULL DEFAULT 0,
        `access` LONGTEXT NULL,
        PRIMARY KEY (`garage_id`),
        KEY `xsg_owner_cid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `xs_garages_impound` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `plate` VARCHAR(16) NOT NULL,
        `citizenid` VARCHAR(64) NOT NULL DEFAULT '',
        `fee` INT NOT NULL DEFAULT 0,
        `release_at` INT NOT NULL DEFAULT 0,
        `reason` VARCHAR(200) NOT NULL DEFAULT '',
        `officer` VARCHAR(100) NOT NULL DEFAULT '',
        `officer_cid` VARCHAR(64) NOT NULL DEFAULT '',
        `at` INT NOT NULL DEFAULT 0,
        `released` TINYINT NOT NULL DEFAULT 0,
        `done` TINYINT NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `xsg_imp_plate` (`plate`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `xs_garages_settings` (
        `name` VARCHAR(64) NOT NULL,
        `data` LONGTEXT NOT NULL,
        PRIMARY KEY (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `xs_garages_logs` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `garage` VARCHAR(64) NOT NULL DEFAULT '',
        `kind` VARCHAR(24) NOT NULL,
        `plate` VARCHAR(16) NOT NULL DEFAULT '',
        `citizenid` VARCHAR(64) NOT NULL DEFAULT '',
        `name` VARCHAR(100) NOT NULL DEFAULT '',
        `detail` VARCHAR(255) NOT NULL DEFAULT '',
        `amount` INT NOT NULL DEFAULT 0,
        `at` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `xsg_log_at` (`at`),
        KEY `xsg_log_plate` (`plate`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

function Db.Setup()
    for _, statement in ipairs(TABLES) do
        local ok, err = pcall(MySQL.query.await, statement)
        if not ok then
            print(('^1[XS-Garages]^0 could not create a table: %s'):format(tostring(err)))
            return false
        end
    end
    local ok, rows = pcall(MySQL.query.await, 'SHOW COLUMNS FROM `player_vehicles`')
    if not ok or type(rows) ~= 'table' or #rows == 0 then
        print('^1[XS-Garages]^0 There is no player_vehicles table. XS-Garages keeps owned cars in the framework\'s player_vehicles table, so start qbx_vehicles or qb-core first.')
        return false
    end
    for _, row in ipairs(rows) do Db.columns[row.Field or row.field or ''] = true end
    if not Db.columns.depotprice then
        pcall(MySQL.query.await, 'ALTER TABLE `player_vehicles` ADD COLUMN `depotprice` INT NOT NULL DEFAULT 0')
        Db.columns.depotprice = true
    end
    if not Db.columns.garage then
        pcall(MySQL.query.await, 'ALTER TABLE `player_vehicles` ADD COLUMN `garage` VARCHAR(50) NULL')
        Db.columns.garage = true
    end
    if not Db.columns.state then
        pcall(MySQL.query.await, 'ALTER TABLE `player_vehicles` ADD COLUMN `state` INT NOT NULL DEFAULT 1')
        Db.columns.state = true
    end
    Db.ready = true
    return true
end

function Db.Json(value)
    local ok, out = pcall(json.encode, value)
    return ok and out or '{}'
end

function Db.Decode(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, out = pcall(json.decode, value)
    if ok and out ~= nil then return out end
    return fallback
end
