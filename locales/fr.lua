-- Français (langue de référence : toute phrase absente d'une autre langue est prise ici)
-- Notifications : le **gras** est supporté. Interface : {day}, {min}, {max} sont remplacés automatiquement.
Locales = Locales or {}

Locales['fr'] = {
    -- Notifications
    notify_title    = 'Récompense journalière',
    available_key   = 'Ta récompense du jour est disponible ! Appuie sur **%s** ou tape **/%s**.',
    available_cmd   = 'Ta récompense du jour est disponible ! Tape **/%s** pour la récupérer.',
    streak_lost     = 'Tu as manqué un jour : ta série repart au jour 1.',
    claimed         = '**Jour %d** · %s',
    already_claimed = 'Tu as déjà récupéré ta récompense aujourd\'hui.',
    inventory_full  = 'Ton inventaire est plein : libère de la place puis réessaie.',
    busy            = 'Réclamation déjà en cours, patiente...',
    error           = 'Une erreur est survenue, réessaie plus tard.',
    keymap          = 'Ouvrir les récompenses journalières',
    log_reason      = 'Récompense journalière',

    -- Logs Discord
    discord = {
        title    = '🎁 Récompense journalière récupérée',
        player   = 'Joueur',
        day      = 'Jour',
        id       = 'Identifiant',
        discord  = 'Discord',
        unknown  = 'Inconnu',
        rewards  = 'Récompenses',
        failed   = '⚠ Items non donnés'
    },

    -- Interface
    ui = {
        tag            = 'Connexion quotidienne',
        copyright      = '© BloodLeak', -- mention discrète en bas du menu ('' pour la retirer)
        title          = 'Récompenses journalières',
        subtitle       = 'Connecte-toi chaque jour pour faire grimper ta série.',
        streak         = 'Série',
        day            = 'JOUR',
        today          = 'Aujourd\'hui',
        claimed        = 'Récupéré',
        locked         = 'Verrouillé',
        next           = 'Prochain',
        big_reward     = 'Grosse récompense',
        claim_button   = 'Récupérer le jour {day}',
        claiming       = 'Validation...',
        claimed_button = 'Récupéré !',
        next_reward    = 'Prochaine récompense dans',
        cycle_done     = 'Cycle terminé ! Un nouveau cycle commence au prochain reset.',
        streak_lost    = 'Tu as manqué un jour : ta série repart au jour 1.',
        reset_warning  = 'Manquer un jour remet ta série à zéro.',
        no_reset       = 'Ta série est conservée même si tu manques un jour.',
        key_escape     = 'ÉCHAP',
        close_hint     = 'pour fermer',
        empty          = 'Aucune récompense',
        currency       = '$',
        money          = 'Liquide',
        bank           = 'Banque',
        black_money    = 'Argent sale',
        bonus          = 'Bonus mystère',
        bonus_range    = '+{min} à {max}',

        -- Raretés
        rarity_common    = 'Commun',
        rarity_rare      = 'Rare',
        rarity_epic      = 'Épique',
        rarity_legendary = 'Légendaire',

        -- Notifications au-dessus du menu
        toast_success = 'Récompense récupérée',
        toast_error   = 'Récupération impossible',
        toast_warning = 'Attention',
        toast_info    = 'Info',

        -- Pop-up d'incitation
        popup_tag     = 'Récompense disponible',
        popup_tag_big = 'Grosse récompense',
        popup_lost    = 'Série perdue, retour au jour 1',
        popup_open    = 'Ouvrir'
    }
}
