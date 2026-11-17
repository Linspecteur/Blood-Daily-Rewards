-- Détection du framework (Config.Framework = 'auto' | 'esx' | 'qbcore')
Bridge = {}

local function detect()
    local wanted = (Config.Framework or 'auto'):lower()
    if wanted == 'esx' or wanted == 'qbcore' then return wanted end

    if GetResourceState('es_extended') ~= 'missing' then return 'esx' end
    if GetResourceState('qb-core') ~= 'missing' then return 'qbcore' end
    return nil
end

Bridge.Framework = detect()

if not Bridge.Framework then
    error('[bl_daily] Aucun framework trouvé : es_extended (ESX) ou qb-core (QBCore) doit être démarré avant bl_daily.')
end
