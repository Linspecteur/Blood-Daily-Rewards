Config = {}

--[[
    ==========================================================
      GÉNÉRAL
    ==========================================================
]]

-- Framework : 'auto' (détecte es_extended ou qb-core), 'esx' ou 'qbcore'
Config.Framework = 'auto'

-- QBCore uniquement : QBCore n'a pas de compte "argent sale".
-- Les récompenses black_money sont données en billets marqués (item, valeur dans metadata.worth).
Config.QBCore = {
    BlackMoneyItem = 'markedbills'
}

-- Langue des textes : nom d'un fichier du dossier locales/ ('fr', 'en', ...)
-- Une phrase absente de la langue choisie est prise dans locales/fr.lua.
Config.Language = 'fr'

-- Commande pour ouvrir l'interface à tout moment (/recompense)
Config.Command = 'recompense'

-- Touche par défaut (RegisterKeyMapping). Le joueur peut la modifier dans
-- Paramètres > Raccourcis clavier > FiveM. Mettre false pour désactiver.
-- ⚠ Changer cette valeur n'affecte pas les joueurs qui ont déjà la touche enregistrée.
Config.OpenKey = 'F9'

-- true = ouvre l'interface directement à la connexion si une récompense est disponible
-- false = affiche la pop-up (en haut à droite) proposant d'ouvrir l'interface
Config.AutoOpen = false

-- Pop-up d'incitation affichée quand une récompense est disponible
Config.Popup = {
    Enabled  = true, -- false = simple notification ox_lib à la place
    Position = 'bottom-right', -- 'bottom-right' | 'top-right' | 'bottom-left' | 'top-left' (bas gauche = minimap GTA)
    Duration = 20,   -- durée d'affichage en secondes (0 = reste affichée jusqu'à l'ouverture du menu)
    Reminder = 15,   -- minutes : réaffiche la pop-up si la récompense n'est toujours pas récupérée (0 = jamais)
    Sound    = true  -- petit son GTA à l'apparition
}

-- Délai (ms) après le chargement du personnage avant la vérification
-- (laisse le temps au multicharacter / spawn de se terminer)
Config.LoginDelay = 8000

-- Inventaire utilisé pour donner les items :
--   'auto'      = ox_inventory s'il est démarré, sinon celui du framework
--   'ox'        = force ox_inventory
--   'framework' = force l'inventaire du framework (ESX de base ou qb-inventory)
Config.Inventory = 'auto'

-- Chemin des images d'items dans l'UI ('%s' = nom de l'item).
-- Si l'image n'existe pas, une icône générique s'affiche. false = toujours l'icône.
Config.ItemImagePath = 'nui://ox_inventory/web/images/%s.png'

-- true  = une série par personnage (ESX : identifier char1:xxxx / QBCore : citizenid)
-- false = une série par compte (licence Rockstar) : empêche de cumuler avec plusieurs personnages
Config.PerCharacter = true

--[[
    ==========================================================
      TEMPS & SÉRIE (calculs faits UNIQUEMENT côté serveur)
    ==========================================================
]]

-- 'midnight' : une récompense par jour calendaire, reset à Config.ResetHour (heure du serveur)
-- 'rolling'  : une récompense toutes les 24h glissantes après la dernière réclamation
Config.ResetMode = 'midnight'

-- Heure du reset en mode 'midnight' (0 = minuit, 6 = 6h du matin, ...)
Config.ResetHour = 0

-- Réglages du mode 'rolling' (en secondes)
Config.Rolling = {
    Cooldown = 24 * 3600, -- délai avant de pouvoir réclamer à nouveau
    Expire   = 48 * 3600  -- au-delà, le jour est considéré comme manqué
}

-- true = si le joueur rate un jour, la série repart au jour 1
Config.ResetOnMissedDay = true

--[[
    ==========================================================
      RÉCOMPENSES (7 jours)
      Clés possibles par jour :
        rarity       = 'common' | 'rare' | 'epic' | 'legendary' (couleur + badge sur la carte)
        label        = titre affiché sur la carte (optionnel) : texte simple,
                       ou une traduction par langue : { fr = '...', en = '...' }
        money        = argent liquide
        bank         = argent en banque
        black_money  = argent sale
        items        = { { name = 'item', count = 1, metadata = {} (ox uniquement, optionnel) } }
        bonus        = { account = 'bank', min = 10000, max = 50000 }
                       -> montant aléatoire tiré CÔTÉ SERVEUR au moment de la réclamation
      Les items doivent exister dans ton inventaire (ox_inventory/data/items.lua ou table `items`).
      Astuce : mets tes items les plus recherchés (crochetage, armure, kit de réparation...)
      sur les jours 5 à 7 pour donner envie de tenir la série.
    ==========================================================
]]
Config.Rewards = {
    [1] = {
        rarity = 'common',
        money = 2500,
        items = { { name = 'bread', count = 5 }, { name = 'water', count = 5 } }
    },
    [2] = {
        rarity = 'common',
        bank = 5000,
        items = { { name = 'bandage', count = 3 } }
    },
    [3] = {
        rarity = 'rare',
        money = 7500,
        items = { { name = 'bandage', count = 5 } }
    },
    [4] = {
        rarity = 'rare',
        bank = 12000,
        items = { { name = 'bread', count = 10 }, { name = 'water', count = 10 } }
    },
    [5] = {
        rarity = 'epic',
        label = { fr = 'Pack de survie', en = 'Survival pack' },
        money = 15000,
        items = { { name = 'bandage', count = 10 }, { name = 'bread', count = 10 }, { name = 'water', count = 10 } }
    },
    [6] = {
        rarity = 'epic',
        money = 10000,
        bank = 20000
    },
    [7] = {
        rarity = 'legendary',
        label = { fr = 'Coffre légendaire', en = 'Legendary chest' },
        money = 25000,
        bank = 50000,
        bonus = { account = 'bank', min = 10000, max = 50000 },
        items = { { name = 'bandage', count = 15 }, { name = 'bread', count = 20 }, { name = 'water', count = 20 } }
    }
}
