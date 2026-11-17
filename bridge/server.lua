--[[
    Pont framework côté serveur : le reste du script n'appelle jamais ESX ou QBCore
    directement, seulement les fonctions Bridge.* ci-dessous.
]]

local ESX, QBCore
if Bridge.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
else
    QBCore = exports['qb-core']:GetCoreObject()
end

-- Comptes du config (noms ESX) -> comptes QBCore
local QB_ACCOUNTS = { money = 'cash', bank = 'bank' }

-- ox_inventory s'il est démarré (ou forcé), sinon l'inventaire du framework
function Bridge.UseOxInventory()
    if Config.Inventory == 'ox' then return true end
    if Config.Inventory == 'framework' or Config.Inventory == 'esx' then return false end
    return GetResourceState('ox_inventory') == 'started'
end

function Bridge.GetItemLabel(name)
    if Bridge.UseOxInventory() then
        local item = exports.ox_inventory:Items(name)
        return item and item.label
    end
    if ESX then return ESX.GetItemLabel(name) end
    local item = QBCore.Shared.Items[name] or QBCore.Shared.Items[name:lower()]
    return item and item.label
end

--[[
    Renvoie un joueur "neutre" ou nil :
      identifier                       identifiant du personnage (ESX : identifier, QBCore : citizenid)
      name                             nom RP
      addMoney(account, amount, why)   account = 'money' | 'bank' | 'black_money'
      canCarry(item, count)            place dans l'inventaire
      addItem(item, count, metadata)   renvoie true si donné
]]
function Bridge.GetPlayer(src)
    local p = {}

    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return nil end

        p.identifier = xPlayer.identifier
        p.name = xPlayer.getName()
        p.addMoney = function(account, amount, reason)
            xPlayer.addAccountMoney(account, amount, reason)
            return true
        end
        p.canCarry = function(item, count) return xPlayer.canCarryItem(item, count) end
        p.addItem = function(item, count)
            xPlayer.addInventoryItem(item, count)
            return true
        end
    else
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return nil end

        local info = Player.PlayerData.charinfo or {}
        p.identifier = Player.PlayerData.citizenid
        p.name = ('%s %s'):format(info.firstname or '', info.lastname or '')
        p.addMoney = function(account, amount, reason)
            -- QBCore n'a pas de compte "argent sale" : on donne des billets marqués
            if account == 'black_money' then
                return p.addItem(Config.QBCore.BlackMoneyItem, 1, { worth = amount })
            end
            return Player.Functions.AddMoney(QB_ACCOUNTS[account] or account, amount, reason)
        end
        p.canCarry = function(item, count)
            -- qb-inventory récent : CanAddItem ; versions anciennes : pas de vérification possible
            local ok, canAdd = pcall(function() return exports['qb-inventory']:CanAddItem(src, item, count) end)
            if ok and canAdd ~= nil then return canAdd end
            return true
        end
        p.addItem = function(item, count, metadata)
            local added = Player.Functions.AddItem(item, count, false, metadata)
            if added and QBCore.Shared.Items[item] then
                TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add', count)
            end
            return added
        end
    end

    -- Items via ox_inventory, quel que soit le framework
    if Bridge.UseOxInventory() then
        p.canCarry = function(item, count) return exports.ox_inventory:CanCarryItem(src, item, count) end
        p.addItem = function(item, count, metadata) return exports.ox_inventory:AddItem(src, item, count, metadata) end
    end

    return p
end

-- Callback serveur : fn(source, cb, ...)
function Bridge.RegisterCallback(name, fn)
    if ESX then
        ESX.RegisterServerCallback(name, fn)
    else
        QBCore.Functions.CreateCallback(name, fn)
    end
end

-- Personnage chargé (connexion ou changement de personnage) : fn(source)
function Bridge.OnPlayerLoaded(fn)
    if ESX then
        AddEventHandler('esx:playerLoaded', function(playerId) fn(playerId) end)
    else
        AddEventHandler('QBCore:Server:PlayerLoaded', function(Player) fn(Player.PlayerData.source) end)
    end
end

print(('^2[bl_daily] Framework : %s | Inventaire : %s^0'):format(
    Bridge.Framework == 'esx' and 'ESX' or 'QBCore',
    Bridge.UseOxInventory() and 'ox_inventory' or (Bridge.Framework == 'esx' and 'ESX' or 'qb-inventory')
))
