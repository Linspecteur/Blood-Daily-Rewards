-- English
-- Notifications support **bold**. UI: {day}, {min}, {max} are replaced automatically.
Locales = Locales or {}

Locales['en'] = {
    -- Notifications
    notify_title    = 'Daily reward',
    available_key   = 'Your daily reward is ready! Press **%s** or type **/%s**.',
    available_cmd   = 'Your daily reward is ready! Type **/%s** to claim it.',
    streak_lost     = 'You missed a day: your streak is back to day 1.',
    claimed         = '**Day %d** · %s',
    already_claimed = 'You have already claimed your reward today.',
    inventory_full  = 'Your inventory is full: make some room and try again.',
    busy            = 'Claim already in progress, please wait...',
    error           = 'Something went wrong, please try again later.',
    keymap          = 'Open daily rewards',
    log_reason      = 'Daily reward',

    -- Discord logs
    discord = {
        title    = '🎁 Daily reward claimed',
        player   = 'Player',
        day      = 'Day',
        id       = 'Identifier',
        discord  = 'Discord',
        unknown  = 'Unknown',
        rewards  = 'Rewards',
        failed   = '⚠ Items not given'
    },

    -- Interface
    ui = {
        tag            = 'Daily login',
        copyright      = '© BloodLeak',
        title          = 'Daily rewards',
        subtitle       = 'Log in every day to grow your streak.',
        streak         = 'Streak',
        day            = 'DAY',
        today          = 'Today',
        claimed        = 'Claimed',
        locked         = 'Locked',
        next           = 'Next',
        big_reward     = 'Big reward',
        claim_button   = 'Claim day {day}',
        claiming       = 'Claiming...',
        claimed_button = 'Claimed!',
        next_reward    = 'Next reward in',
        cycle_done     = 'Cycle complete! A new cycle starts at the next reset.',
        streak_lost    = 'You missed a day: your streak is back to day 1.',
        reset_warning  = 'Missing a day resets your streak.',
        no_reset       = 'Your streak is kept even if you miss a day.',
        key_escape     = 'ESC',
        close_hint     = 'to close',
        empty          = 'No reward',
        currency       = '$',
        money          = 'Cash',
        bank           = 'Bank',
        black_money    = 'Dirty money',
        bonus          = 'Mystery bonus',
        bonus_range    = '+{min} to {max}',

        -- Rarities
        rarity_common    = 'Common',
        rarity_rare      = 'Rare',
        rarity_epic      = 'Epic',
        rarity_legendary = 'Legendary',

        -- Notifications above the menu
        toast_success = 'Reward claimed',
        toast_error   = 'Cannot claim',
        toast_warning = 'Warning',
        toast_info    = 'Info',

        -- Login pop-up
        popup_tag     = 'Reward available',
        popup_tag_big = 'Big reward',
        popup_lost    = 'Streak lost, back to day 1',
        popup_open    = 'Open'
    }
}
