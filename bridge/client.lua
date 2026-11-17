-- Pont framework côté client

local ESX, QBCore
if Bridge.Framework == 'esx' then
    ESX = exports['es_extended']:getSharedObject()
else
    QBCore = exports['qb-core']:GetCoreObject()
end

-- Callback serveur : cb(résultat)
function Bridge.TriggerCallback(name, cb, ...)
    if ESX then
        ESX.TriggerServerCallback(name, cb, ...)
    else
        QBCore.Functions.TriggerCallback(name, cb, ...)
    end
end

function Bridge.IsPlayerLoaded()
    if ESX then return ESX.IsPlayerLoaded() end
    return LocalPlayer.state.isLoggedIn == true
end

-- Déconnexion / changement de personnage : fn()
function Bridge.OnPlayerLogout(fn)
    RegisterNetEvent(ESX and 'esx:onPlayerLogout' or 'QBCore:Client:OnPlayerUnload', fn)
end
