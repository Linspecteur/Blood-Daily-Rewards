-- bl_daily : série de récompenses journalières
-- last_claim est un timestamp Unix (os.time() côté serveur), 0 = jamais réclamé.
-- Stocké en entier pour éviter tout décalage de fuseau horaire entre MySQL et Lua.

CREATE TABLE IF NOT EXISTS `daily_rewards` (
    `identifier` VARCHAR(60)      NOT NULL,
    `streak`     TINYINT UNSIGNED NOT NULL DEFAULT 0,
    `last_claim` INT UNSIGNED     NOT NULL DEFAULT 0,
    PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
