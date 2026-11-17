-- ESX / QBCore : tout passe par Bridge (voir bridge/client.lua)
local L = Config.Locale

local isOpen = false      -- interface ouverte
local isFetching = false  -- demande d'ouverture en cours (évite les doubles ouvertures)
local scheduleToken = 0   -- invalide les vérifications programmées précédentes

--[[ ========================================================
      UTILITAIRES
======================================================== ]]

local function notify(description, kind)
    lib.notify({
        title = L.notify_title,
        description = description,
        type = kind or 'inform',
        icon = 'gift',
        duration = 7000
    })
end

-- Touche réellement assignée par le joueur (s'il l'a modifiée), sinon celle du config
local function getKeyLabel()
    if not Config.OpenKey then return false end
    local label = GetControlInstructionalButton(0, joaat(Config.Command) | 0x80000000, true)
    if type(label) == 'string' and label:sub(1, 2) == 't_' then
        return label:sub(3)
    end
    return Config.OpenKey
end

--[[ ========================================================
      POP-UP D'INCITATION & RAPPELS
======================================================== ]]

local showPopup -- déclarée plus bas

-- Programme UNE vérification dans `seconds` secondes (timer natif, aucune boucle).
-- Si une récompense est disponible à ce moment-là, la pop-up s'affiche.
local function scheduleCheck(seconds)
    scheduleToken = scheduleToken + 1
    if not seconds or seconds <= 0 then return end

    local token = scheduleToken
    SetTimeout(math.floor(seconds * 1000), function()
        if token ~= scheduleToken then return end
        if isOpen then return scheduleCheck(60) end -- menu ouvert : on revérifie plus tard

        Bridge.TriggerCallback('bl_daily:getStatus', function(status)
            if token ~= scheduleToken then return end
            if not status then return scheduleCheck(30) end

            if status.canClaim then
                showPopup(status)
            else
                scheduleCheck(status.nextIn + 2)
            end
        end)
    end)
end

showPopup = function(status)
    if isOpen then return end

    if Config.Popup.Enabled then
        SendNUIMessage({
            action = 'popup',
            status = status,
            locale = L.ui,
            key = getKeyLabel(),
            command = Config.Command,
            duration = Config.Popup.Duration,
            position = Config.Popup.Position
        })
        if Config.Popup.Sound then
            PlaySoundFrontend(-1, 'CHALLENGE_UNLOCKED', 'HUD_AWARDS', true)
        end
    else
        if status.streakLost then notify(L.streak_lost, 'warning') end
        if Config.OpenKey then
            notify(L.available_key:format(getKeyLabel(), Config.Command), 'success')
        else
            notify(L.available_cmd:format(Config.Command), 'success')
        end
    end

    -- Rappel si le joueur ne récupère pas sa récompense
    if Config.Popup.Reminder > 0 then
        scheduleCheck(Config.Popup.Reminder * 60)
    end
end

--[[ ========================================================
      OUVERTURE / FERMETURE
======================================================== ]]

local function openUI()
    if isOpen or isFetching or IsPauseMenuActive() then return end
    isFetching = true

    Bridge.TriggerCallback('bl_daily:getStatus', function(status)
        isFetching = false
        if not status or isOpen then return end

        isOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open', status = status, locale = L.ui }) -- masque aussi la pop-up
    end)
end

local function closeUI()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterCommand(Config.Command, openUI, false)

if Config.OpenKey then
    RegisterKeyMapping(Config.Command, L.keymap, 'keyboard', Config.OpenKey)
end

--[[ ========================================================
      CALLBACKS NUI
======================================================== ]]

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb('ok')
end)

-- Le client demande seulement "claim" : aucun montant ni item n'est envoyé.
-- Le message est affiché par l'interface elle-même (au-dessus du menu).
RegisterNUICallback('claim', function(_, cb)
    Bridge.TriggerCallback('bl_daily:claim', function(result)
        result = result or { ok = false, message = L.error }

        if result.ok then
            result.message = L.claimed:format(result.day, result.summary)
            -- Prochaine pop-up au prochain reset
            if result.status then scheduleCheck(result.status.nextIn + 2) end
        else
            result.message = result.message or L.error
        end

        cb(result)
    end)
end)

-- Rafraîchissement demandé par l'UI quand le compte à rebours arrive à 0
RegisterNUICallback('refresh', function(_, cb)
    Bridge.TriggerCallback('bl_daily:getStatus', function(status)
        cb(status or false)
    end)
end)

--[[ ========================================================
      ÉVÉNEMENTS
======================================================== ]]

local function handleStatus(status, autoOpen)
    if status.canClaim then
        if autoOpen then
            openUI() -- le bandeau "série perdue" s'affiche dans le menu
        else
            showPopup(status)
        end
    else
        scheduleCheck(status.nextIn + 2)
    end
end

-- Envoyé par le serveur quand le personnage est chargé
RegisterNetEvent('bl_daily:onLogin', function(status, autoOpen)
    if status then handleStatus(status, autoOpen) end
end)

-- Redémarrage de la ressource en jeu : on revérifie (pratique pour les tests)
AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() or not Bridge.IsPlayerLoaded() then return end
    SetTimeout(3000, function()
        Bridge.TriggerCallback('bl_daily:getStatus', function(status)
            if status then handleStatus(status, false) end
        end)
    end)
end)

-- Changement de personnage : on ferme tout et on annule les rappels
Bridge.OnPlayerLogout(function()
    scheduleToken = scheduleToken + 1
    closeUI()
    SendNUIMessage({ action = 'hidePopup' })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and isOpen then
        SetNuiFocus(false, false)
    end
end)
