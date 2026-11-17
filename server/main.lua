-- ESX / QBCore : tout passe par Bridge (voir bridge/server.lua)
local L = Config.Locale

local CYCLE = #Config.Rewards               -- longueur du cycle (7)
local DAY = 86400
local ACCOUNTS = { 'money', 'bank', 'black_money' }
local STATUS_THROTTLE = 750                 -- ms minimum entre deux demandes de statut

local claimLocks = {}    -- [source] = true pendant le traitement d'une réclamation
local lastStatusReq = {} -- [source] = GetGameTimer() de la dernière demande
local rewardsCache       -- récompenses formatées pour l'UI (labels résolus)

--[[ ========================================================
      UTILITAIRES
======================================================== ]]

local function formatNumber(n)
    local s = tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1 '):reverse()
    return (s:gsub('^ ', ''))
end

-- Identifiant de la série : par personnage ou par licence (voir Config.PerCharacter)
local function getIdentifier(src, player)
    if Config.PerCharacter then return player.identifier end
    return GetPlayerIdentifierByType(src, 'license') or player.identifier
end

--[[ ========================================================
      TEMPS (os.time() serveur uniquement)
======================================================== ]]

-- Numéro de "jour" local en tenant compte de l'heure de reset.
-- On prend midi du jour concerné pour rester insensible aux changements d'heure.
local function dayNumber(t)
    local d = os.date('*t', t - Config.ResetHour * 3600)
    return math.floor(os.time({ year = d.year, month = d.month, day = d.day, hour = 12 }) / DAY)
end

-- Timestamp du prochain reset (mode 'midnight')
local function nextResetAt(now)
    local d = os.date('*t', now - Config.ResetHour * 3600)
    return os.time({ year = d.year, month = d.month, day = d.day + 1, hour = Config.ResetHour, min = 0, sec = 0 })
end

--[[ ========================================================
      RÉCOMPENSES (format UI)
======================================================== ]]

local function buildRewards()
    if rewardsCache then return rewardsCache end

    local list = {}
    for day = 1, CYCLE do
        local reward = Config.Rewards[day] or {}
        local entries = {}

        for _, account in ipairs(ACCOUNTS) do
            local amount = tonumber(reward[account])
            if amount and amount > 0 then
                entries[#entries + 1] = { type = account, amount = amount }
            end
        end

        -- Bonus aléatoire : l'UI n'affiche que la fourchette, le tirage se fait à la réclamation
        if reward.bonus then
            entries[#entries + 1] = {
                type = 'bonus',
                account = reward.bonus.account or 'bank',
                min = reward.bonus.min,
                max = reward.bonus.max
            }
        end

        for _, item in ipairs(reward.items or {}) do
            entries[#entries + 1] = {
                type = 'item',
                name = item.name,
                count = item.count or 1,
                label = Config.Translate(item.label) or Bridge.GetItemLabel(item.name) or item.name
            }
        end

        list[day] = { day = day, label = Config.Translate(reward.label), rarity = reward.rarity or 'common', entries = entries }
    end

    rewardsCache = list
    return list
end

-- Résumé texte d'une récompense (notifications + logs)
-- bonusAmount = montant réellement tiré (sinon la fourchette est affichée)
local function rewardSummary(day, bonusAmount)
    local parts = {}
    for _, e in ipairs(buildRewards()[day].entries) do
        if e.type == 'item' then
            parts[#parts + 1] = ('%dx %s'):format(e.count, e.label)
        elseif e.type == 'bonus' then
            local amount = bonusAmount and formatNumber(bonusAmount)
                or ('%s-%s'):format(formatNumber(e.min), formatNumber(e.max))
            parts[#parts + 1] = ('%s %s (%s)'):format(amount, L.ui.currency, L.ui.bonus)
        else
            parts[#parts + 1] = ('%s %s (%s)'):format(formatNumber(e.amount), L.ui.currency, L.ui[e.type])
        end
    end
    return table.concat(parts, ', ')
end

--[[ ========================================================
      STATUT DU JOUEUR
======================================================== ]]

local function fetchRow(identifier)
    local row = MySQL.single.await('SELECT streak, last_claim FROM daily_rewards WHERE identifier = ?', { identifier })
    if not row then
        MySQL.insert.await('INSERT IGNORE INTO daily_rewards (identifier, streak, last_claim) VALUES (?, 0, 0)', { identifier })
        row = { streak = 0, last_claim = 0 }
    end
    return row
end

-- Calcule l'état de la série à partir de la ligne SQL et de l'heure serveur
local function computeStatus(row, now)
    local savedStreak = tonumber(row.streak) or 0
    local last = tonumber(row.last_claim) or 0
    local streak = savedStreak
    local canClaim, nextAt, missed = true, nil, false

    if last > 0 then
        if Config.ResetMode == 'rolling' then
            local elapsed = now - last
            if elapsed < Config.Rolling.Cooldown then
                canClaim, nextAt = false, last + Config.Rolling.Cooldown
            elseif elapsed >= Config.Rolling.Expire then
                missed = true
            end
        else
            local diff = dayNumber(now) - dayNumber(last)
            if diff <= 0 then
                canClaim, nextAt = false, nextResetAt(now)
            elseif diff > 1 then
                missed = true
            end
        end
    end

    local streakLost = false
    if canClaim then
        if missed and Config.ResetOnMissedDay then
            streakLost = savedStreak > 0 and savedStreak < CYCLE
            streak = 0
        end
        if streak >= CYCLE then streak = 0 end -- cycle terminé : on recommence au jour 1
    end

    return {
        canClaim = canClaim,
        streak = streak,                                                   -- jours validés dans le cycle
        nextDay = canClaim and (streak + 1) or ((streak % CYCLE) + 1),     -- jour à réclamer / prochain jour
        nextIn = nextAt and math.max(0, nextAt - now) or 0,                -- secondes avant la prochaine récompense
        streakLost = streakLost
    }
end

-- Ajoute les données d'affichage au statut
local function decorate(status)
    status.rewards = buildRewards()
    status.cycle = CYCLE
    status.resetOnMiss = Config.ResetOnMissedDay
    status.imagePath = Config.ItemImagePath or false
    return status
end

local function getStatus(src)
    local player = Bridge.GetPlayer(src)
    if not player then return nil end
    local row = fetchRow(getIdentifier(src, player))
    return decorate(computeStatus(row, os.time()))
end

--[[ ========================================================
      LOGS DISCORD
======================================================== ]]

local function sendLog(src, player, identifier, day, summary, failed)
    local hook = ServerConfig.Webhook
    if not hook.Enabled or hook.Url == '' then return end

    local D = L.discord
    local discord = GetPlayerIdentifierByType(src, 'discord')
    local fields = {
        { name = D.player, value = ('%s (ID %d)'):format(player.name, src), inline = true },
        { name = D.day, value = ('%d / %d'):format(day, CYCLE), inline = true },
        { name = D.id, value = ('`%s`'):format(identifier), inline = false },
        { name = D.discord, value = discord and ('<@%s>'):format(discord:sub(9)) or D.unknown, inline = true },
        { name = D.rewards, value = summary ~= '' and summary:gsub('%*%*', '') or '-', inline = false }
    }
    if #failed > 0 then
        fields[#fields + 1] = { name = D.failed, value = table.concat(failed, ', '), inline = false }
    end

    PerformHttpRequest(hook.Url, function() end, 'POST', json.encode({
        username = hook.Username,
        avatar_url = hook.Avatar ~= '' and hook.Avatar or nil,
        embeds = { {
            title = D.title,
            color = hook.Color,
            fields = fields,
            footer = { text = os.date('%d/%m/%Y %H:%M:%S') }
        } }
    }), { ['Content-Type'] = 'application/json' })
end

--[[ ========================================================
      RÉCLAMATION
======================================================== ]]

local function processClaim(src)
    local player = Bridge.GetPlayer(src)
    if not player then return { ok = false, message = L.error } end

    local identifier = getIdentifier(src, player)
    local now = os.time()
    local row = fetchRow(identifier)
    local status = computeStatus(row, now)

    if not status.canClaim then
        return { ok = false, message = L.already_claimed, status = decorate(status) }
    end

    local day = status.nextDay
    local reward = Config.Rewards[day]

    -- 1) Vérifie la place dans l'inventaire AVANT toute écriture
    for _, item in ipairs(reward.items or {}) do
        if not player.canCarry(item.name, item.count or 1) then
            return { ok = false, message = L.inventory_full }
        end
    end

    -- 2) Écriture conditionnelle : ne passe que si last_claim n'a pas changé entre-temps
    --    (protection contre toute double réclamation, même hors verrou)
    local affected = MySQL.update.await(
        'UPDATE daily_rewards SET streak = ?, last_claim = ? WHERE identifier = ? AND last_claim = ?',
        { day, now, identifier, tonumber(row.last_claim) or 0 }
    )
    if affected ~= 1 then
        return { ok = false, message = L.already_claimed }
    end

    -- 3) Distribution (le serveur décide de tout, le client n'envoie rien)
    for _, account in ipairs(ACCOUNTS) do
        local amount = tonumber(reward[account])
        if amount and amount > 0 then
            player.addMoney(account, amount, L.log_reason)
        end
    end

    -- Bonus mystère : tiré au sort ici, jamais côté client
    local bonusAmount
    if reward.bonus then
        bonusAmount = math.random(reward.bonus.min, reward.bonus.max)
        player.addMoney(reward.bonus.account or 'bank', bonusAmount, L.log_reason)
    end

    local failed = {}
    for _, item in ipairs(reward.items or {}) do
        local count = item.count or 1
        if not player.addItem(item.name, count, item.metadata) then
            failed[#failed + 1] = ('%dx %s'):format(count, item.name)
            print(('^3[bl_daily] Impossible de donner %dx %s à %s (ID %d)^0'):format(count, item.name, identifier, src))
        end
    end

    local summary = rewardSummary(day, bonusAmount)
    sendLog(src, player, identifier, day, summary, failed)

    return {
        ok = true,
        day = day,
        summary = summary,
        status = decorate(computeStatus({ streak = day, last_claim = now }, now))
    }
end

--[[ ========================================================
      CALLBACKS & ÉVÉNEMENTS
======================================================== ]]

Bridge.RegisterCallback('bl_daily:getStatus', function(src, cb)
    local timer = GetGameTimer()
    if lastStatusReq[src] and timer - lastStatusReq[src] < STATUS_THROTTLE then
        return cb(nil)
    end
    lastStatusReq[src] = timer
    cb(getStatus(src))
end)

Bridge.RegisterCallback('bl_daily:claim', function(src, cb)
    -- Anti-spam : une seule réclamation à la fois par joueur
    if claimLocks[src] then
        return cb({ ok = false, message = L.busy })
    end
    claimLocks[src] = true

    local ok, result = pcall(processClaim, src)
    claimLocks[src] = nil

    if not ok then
        print(('^1[bl_daily] Erreur lors de la réclamation (ID %d) : %s^0'):format(src, result))
        result = { ok = false, message = L.error }
    end
    cb(result)
end)

-- Vérification à la connexion (et à chaque changement de personnage)
Bridge.OnPlayerLoaded(function(playerId)
    SetTimeout(Config.LoginDelay, function()
        if not Bridge.GetPlayer(playerId) then return end
        local status = getStatus(playerId)
        if status then
            -- Statut complet : la pop-up affiche l'aperçu de la récompense du jour
            TriggerClientEvent('bl_daily:onLogin', playerId, status, Config.AutoOpen)
        end
    end)
end)

AddEventHandler('playerDropped', function()
    claimLocks[source] = nil
    lastStatusReq[source] = nil
end)

-- Vérification de la configuration au démarrage
CreateThread(function()
    if CYCLE ~= 7 then
        print(('^3[bl_daily] Config.Rewards contient %d jours (7 attendus pour l\'interface).^0'):format(CYCLE))
    end
    if Config.ResetMode ~= 'midnight' and Config.ResetMode ~= 'rolling' then
        print('^1[bl_daily] Config.ResetMode invalide, utilise \'midnight\' ou \'rolling\'.^0')
    end
    for day, reward in pairs(Config.Rewards) do
        local b = reward.bonus
        if b and (type(b.min) ~= 'number' or type(b.max) ~= 'number' or b.min > b.max) then
            print(('^1[bl_daily] Bonus invalide au jour %d (min/max).^0'):format(day))
            reward.bonus = nil
        end
    end

    -- Items inexistants dans l'inventaire : prévient tout de suite au lieu d'échouer en jeu
    Wait(3000) -- laisse l'inventaire charger ses items
    for day, reward in pairs(Config.Rewards) do
        for _, item in ipairs(reward.items or {}) do
            local ok, label = pcall(Bridge.GetItemLabel, item.name)
            if not ok or not label then
                print(('^3[bl_daily] Jour %d : l\'item "%s" n\'existe pas dans ton inventaire. Modifie Config.Rewards.^0'):format(day, item.name))
            end
        end
    end
end)
