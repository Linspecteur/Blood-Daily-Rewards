-- ⚠ Fichier chargé UNIQUEMENT côté serveur (voir fxmanifest) :
-- l'URL du webhook n'est jamais téléchargée par les clients.
ServerConfig = {}

ServerConfig.Webhook = {
    Enabled  = false,
    Url      = '', -- https://discord.com/api/webhooks/...
    Username = 'Récompenses journalières',
    Avatar   = '', -- URL d'image (optionnel)
    Color    = 15010068 -- #E50914 en décimal
}
