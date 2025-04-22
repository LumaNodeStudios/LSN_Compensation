local Webhook = ''
require('@qbx_core/modules/lib')

lib.addCommand('createcomp', {
    help = 'Open the compensation code creation menu',
    restricted = 'admin'
}, function(source)
    TriggerClientEvent('openCompensationAdminMenu', source)
end)

lib.addCommand('claimmenu', {
    help = 'Open the compensation claim menu'
}, function(source)
    TriggerClientEvent('openCompensationClaimMenu', source)
end)

lib.callback.register("LNS_Compensation:createCode", function(source, data)
    local xPlayer = exports.qbx_core:GetPlayer(source)
    if not xPlayer then return false end

    if not exports.qbx_core:HasPermission(source, "admin") then return false end

    if not data.code or not data.type then return false end

    if data.type == "item" then
        if not data.items or #data.items == 0 then return false end

        for _, v in pairs(data.items) do
            if not v.item or not v.amount or tonumber(v.amount) < 1 then
                return false
            end
        end

        local query = "INSERT INTO compensation_codes (code, type, item, amount, created_by) VALUES "
        local params = {}

        for _, v in pairs(data.items) do
            query = query .. "(?, 'item', ?, ?, ?),"
            table.insert(params, data.code)
            table.insert(params, v.item)
            table.insert(params, v.amount)
            table.insert(params, xPlayer.PlayerData.citizenid)
        end

        query = query:sub(1, -2)

        local inserted = MySQL.insert.await(query, params)
    
        if inserted and inserted > 0 then
            sendToDiscord(
                'Compensation Code Created',
                '**Admin:** ' .. xPlayer.PlayerData.name ..
                '\n**Code:** ' .. data.code ..
                '\n**Type:** Item' ..
                '\n**Items:** ' .. json.encode(data.items),
                Webhook
            )
            return true
        end
    elseif data.type == "vehicle" then
        if not data.vehicle or not data.vehicle.model or not data.vehicle.plate then return false end

        local query = "INSERT INTO compensation_codes (code, type, vehicle_model, vehicle_plate, vehicle_mods, created_by) VALUES (?, 'vehicle', ?, ?, ?, ?)"
        local inserted = MySQL.insert.await(query, { data.code, data.vehicle.model, data.vehicle.plate, data.vehicle.mods, xPlayer.PlayerData.citizenid })

        if inserted and inserted > 0 then
            sendToDiscord(
                'Compensation Code Created',
                '**Admin:** ' .. xPlayer.PlayerData.name ..
                '\n**Code:** ' .. data.code ..
                '\n**Type:** Vehicle' ..
                '\n**Vehicle Model:** ' .. data.vehicle.model ..
                '\n**Plate:** ' .. data.vehicle.plate,
                Webhook
            )
            return true
        end
    end

    return false
end)

lib.callback.register('LNS_Compensation:claimCode', function(source, data, vehicle)
    local xPlayer = exports.qbx_core:GetPlayer(source)
    if not xPlayer then return false end

    local code = data.code
    if not code or code == "" then return false end

    local result = MySQL.query.await('SELECT * FROM compensation_codes WHERE code = ?', { code })

    if result and #result > 0 then
        local success = true
        local compData = result[1]

        if compData.type == "item" then
            for _, v in pairs(result) do
                local itemAdded = exports.ox_inventory:AddItem(source, v.item, v.amount)
                if not itemAdded then
                    success = false
                end
            end
        elseif compData.type == "vehicle" then
            if Settings.Garage == 'jg' then
                local citizenid = xPlayer.PlayerData.citizenid
                local license = xPlayer.PlayerData.license
                local vehicleModel = compData.vehicle_model
                local vehiclePlate = compData.vehicle_plate
                local vehicleMods = json.decode(compData.vehicle_mods)
                local fuel = compData.fuel or 100
                local engine = compData.engine or 1000.0
                local body = compData.body or 1000.0
                local drivingDistance = compData.driving_distance or 0
                local status = compData.status or json.encode({})
        
                local plateCheck = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate = ?', { vehiclePlate })
        
                if plateCheck and #plateCheck > 0 then
                    TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'A vehicle with this plate already exists in the database!' })
                    return false
                end
        
                local insertVehicle = MySQL.insert.await('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, fakeplate, garage, fuel, engine, body, state, depotprice, drivingdistance, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {license, citizenid, vehicleModel, joaat(vehicleModel), json.encode(vehicleMods), vehiclePlate, nil, "Legion Square", fuel, engine, body, 1, 0, drivingDistance, status})
        
                if not insertVehicle then
                    success = false
                end
            --[[elseif Settings.Garage == 'qbx' then
                local citizenid = xPlayer.PlayerData.citizenid
                local license = xPlayer.PlayerData.license
                local vehicleModel = compData.vehicle_model
                local vehiclePlate = compData.vehicle_plate
                local vehicleMods = compData.vehicle_mods and json.decode(compData.vehicle_mods) or {}
                if next(vehicleMods) == nil then
                    vehicleMods = "{}"
                else
                    vehicleMods = json.encode(vehicleMods)
                end
                local fuel = compData.fuel or 100
                local engine = compData.engine or 1000.0
                local body = compData.body or 1000.0
                local drivingDistance = compData.driving_distance or 0
                local status = compData.status or json.encode({})

                local plateCheck = MySQL.single.await('SELECT plate FROM player_vehicles WHERE plate = ?', { vehiclePlate })

                if plateCheck then
                    TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'A vehicle with this plate already exists in the database!' })
                    return false
                end

                local insertVehicle = MySQL.insert.await(
                    'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, fakeplate, garage, fuel, engine, body, state, depotprice, drivingdistance, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', 
                    {
                        license,
                        citizenid,
                        vehicleModel,
                        joaat(vehicleModel),
                        vehicleMods,
                        vehiclePlate,
                        nil,
                        "pillboxgarage",
                        fuel,
                        engine,
                        body,
                        1,
                        0,
                        drivingDistance,
                        status
                    }
                )

                if not insertVehicle then
                    TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Failed to insert vehicle into the database.' })
                    return false
                end

                return true]]
            end
        end        

        if success then
            MySQL.query.await('DELETE FROM compensation_codes WHERE code = ?', { code })

            sendToDiscord('Compensation Claimed', '**Player:** ' .. xPlayer.PlayerData.name .. '\n**Code:** ' .. code, Webhook)

            TriggerClientEvent('ox_lib:notify', source, { type = 'success', description = 'Compensation successfully added to your garage!' })
            return true
        else
            TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Failed to claim compensation!' })
            return false
        end
    else
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Invalid or already claimed code!' })
        return false
    end
end)

function sendToDiscord(title, message, webhook)
    local logs = json.encode({
        username = 'Compensation Logs',
        content = " ",
        embeds = { {
            title = title,
            description = message,
            color = 3918068
        } }
    })

    PerformHttpRequest(webhook, function(err, text, headers)
        if err ~= 200 and err ~= 204 then
            print('Discord Webhook failed! HTTP Code: ' .. err .. ' Response: ' .. (text or "nil"))
        else
            print("Webhook successfully sent: " .. title)
        end
    end, 'POST', logs, { ['Content-Type'] = 'application/json' })
end

lib.versionCheck('LumaNodeStudios/LSN_Compensation')