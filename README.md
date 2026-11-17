<div align="center">
  <img src="https://img.shields.io/badge/FiveM-Script-orange?style=for-the-badge&logo=fivem&logoColor=white" />
  <img src="https://img.shields.io/badge/Framework-ESX%20%7C%20QBCore-blue?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Author-BloodLeak-purple?style=for-the-badge" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" />

  <h1>🎁 Daily Rewards (bl_daily)</h1>
  <p><i>Récompenses journalières sur 7 jours, avec série, raretés et pop-up de connexion</i></p>
</div>

---

## 📖 À propos

**bl_daily** récompense les joueurs qui se connectent chaque jour. Une série de 7 jours fait monter la valeur des récompenses jusqu'à un coffre légendaire au jour 7. Si le joueur manque un jour, la série repart au jour 1 (désactivable).

Toute la logique est faite **côté serveur** : le client ne fait que demander « je récupère ». Le serveur vérifie le délai, choisit la récompense et la distribue. Aucune boucle `Wait(0)`, 0.00 ms au repos.

---

## ✨ Fonctionnalités

### 📅 Calendrier de 7 jours
- Jours récupérés (tamponnés), jour actuel mis en avant, jours à venir verrouillés mais visibles pour donner envie.
- **Raretés** par jour : Commun, Rare, Épique, Légendaire (couleur et badge sur chaque carte).
- **Jour 7** : grande carte dédiée, puis le cycle recommence.
- **Compte à rebours** jusqu'à la prochaine récompense.

### 💰 Récompenses configurables
- Liquide, banque, argent sale, items, ou plusieurs à la fois.
- **Bonus mystère** : montant aléatoire tiré au sort par le serveur au moment de la réclamation (ex : +10 000 à 50 000 $).
- Titre personnalisé par carte, traduisible par langue.

### 🔔 Pop-up de connexion
- Pop-up compacte qui invite à ouvrir le menu (jour, montant, rareté, touche).
- Position au choix (4 coins), durée, rappel automatique si la récompense n'est pas récupérée, son.
- Ou ouverture automatique du menu à la connexion (`Config.AutoOpen`).

### 🔒 Sécurité
- Délai vérifié uniquement côté serveur avec `os.time()` (minuit / heure de reset au choix, ou 24 h glissantes).
- Le client n'envoie jamais de montant ni d'item.
- Verrou anti-spam pendant chaque réclamation **et** écriture SQL conditionnelle : impossible de récupérer deux fois.
- Place dans l'inventaire vérifiée **avant** de valider : rien n'est perdu si l'inventaire est plein.
- Option une série par personnage ou **par compte** (empêche de cumuler avec plusieurs personnages).
- Logs Discord optionnels (webhook jamais envoyé aux joueurs).

### 🧩 Compatibilité
- **ESX** et **QBCore**, détectés automatiquement.
- **ox_inventory**, inventaire ESX ou **qb-inventory**, détectés automatiquement.
- **Multilingue** : français et anglais inclus, ajout d'une langue en un fichier.

---

## 📦 Dépendances

| Ressource | Obligatoire |
| :--- | :--- |
| [es_extended](https://github.com/esx-framework/esx_core) **ou** [qb-core](https://github.com/qbcore-framework/qb-core) | ✅ |
| [oxmysql](https://github.com/overextended/oxmysql) | ✅ |
| [ox_lib](https://github.com/overextended/ox_lib) | ✅ (notifications) |
| [ox_inventory](https://github.com/overextended/ox_inventory) | ➖ Optionnel |

---

## 🚀 Installation

1. Placez le dossier `bl_daily` dans votre répertoire de ressources.
2. Exécutez le fichier [sql/daily_rewards.sql](sql/daily_rewards.sql) dans votre base de données.
3. Ajoutez dans votre `server.cfg`, **après** votre framework, oxmysql, ox_lib et votre inventaire :
   ```cfg
   ensure bl_daily
   ```
4. **Important :** adaptez les items de `Config.Rewards` à votre serveur. Les exemples (`bread`, `water`, `bandage`) n'existent pas sur tous les inventaires. Au démarrage, la console affiche un avertissement pour chaque item introuvable.
5. Démarrez votre serveur.

---

## 📋 Configuration (`config.lua`)

```lua
Config.Framework  = 'auto'        -- 'auto' | 'esx' | 'qbcore'
Config.Language   = 'fr'          -- fichier du dossier locales/
Config.Command    = 'recompense'  -- /recompense
Config.OpenKey    = 'F9'          -- touche (modifiable par le joueur)

Config.ResetMode        = 'midnight' -- 'midnight' (reset à Config.ResetHour) ou 'rolling' (24 h)
Config.ResetHour        = 0
Config.ResetOnMissedDay = true       -- un jour manqué = retour au jour 1

Config.Rewards = {
    [1] = { rarity = 'common', money = 2500, items = { { name = 'water', count = 5 } } },
    -- ...
    [7] = {
        rarity = 'legendary',
        label  = { fr = 'Coffre légendaire', en = 'Legendary chest' },
        money  = 25000,
        bank   = 50000,
        bonus  = { account = 'bank', min = 10000, max = 50000 }
    }
}
```

Le webhook Discord se règle dans `config_server.lua` (fichier jamais envoyé aux joueurs).

> **QBCore :** QBCore n'a pas de compte « argent sale ». Les récompenses `black_money` sont données en billets marqués (`Config.QBCore.BlackMoneyItem`, `markedbills` par défaut).

---

## 🌍 Langues

Les textes sont dans le dossier `locales/` (`fr.lua`, `en.lua`). Pour ajouter une langue :
1. Copiez `locales/fr.lua` en `locales/es.lua`.
2. Remplacez `Locales['fr']` par `Locales['es']` et traduisez.
3. Mettez `Config.Language = 'es'`.

Une phrase oubliée s'affiche en français au lieu de casser l'interface.

---

## 🎮 Commandes & Événements

| Commande / Événement | Type | Description |
| :--- | :--- | :--- |
| `/recompense` | Commande | Ouvre le menu des récompenses (nom configurable) |
| `F9` | Touche | Ouvre le menu (modifiable dans Paramètres > Raccourcis clavier > FiveM) |
| `bl_daily:onLogin` | Client Event | Envoyé par le serveur quand le personnage est chargé (pop-up ou ouverture auto) |

---

<div align="center">
  <p><i>Développé par <b>BloodLeak</b>.</i></p>
</div>
