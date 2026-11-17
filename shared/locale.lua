-- Choisit la langue (Config.Language) et complète les phrases manquantes avec le français.
-- Le reste du script continue d'utiliser Config.Locale.

local function fill(target, reference)
    for key, value in pairs(reference) do
        if target[key] == nil then
            target[key] = value
        elseif type(value) == 'table' and type(target[key]) == 'table' then
            fill(target[key], value)
        end
    end
    return target
end

local base = Locales['fr']
local chosen = Locales[Config.Language]

if not chosen then
    print(('^3[bl_daily] Langue "%s" introuvable dans locales/, utilisation du français.^0'):format(tostring(Config.Language)))
    chosen = {}
end

Config.Locale = fill(chosen, base)

-- Texte d'une récompense : chaîne simple ou { fr = '...', en = '...' }
function Config.Translate(text)
    if type(text) ~= 'table' then return text end
    return text[Config.Language] or text.fr or select(2, next(text))
end
