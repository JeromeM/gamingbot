#!/bin/bash
# entrypoint.sh

# Afficher l'environnement pour déboguer
echo "Environnement de gamingbot :"
env

# Vérifier que les variables nécessaires sont définies
if [ -z "$VAULT_ADDR" ] || [ -z "$VAULT_TOKEN" ]; then
  echo "Erreur : VAULT_ADDR et VAULT_TOKEN doivent être définis" >&2
  exit 1
fi

# Vérifier la connexion à Vault
echo "Vérification de la connexion à Vault..."
wget -q -O - http://vault:8200/v1/sys/health || {
  echo "Erreur : Impossible de se connecter à Vault" >&2
  exit 1
}

# Récupérer le token Discord depuis Vault
echo "Récupération du token Discord depuis Vault..."
CURL_RESPONSE=$(curl -s --header "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/secret/data/gamingbot" 2>&1)
if [ $? -ne 0 ]; then
  echo "Erreur : Échec de la requête curl : $CURL_RESPONSE" >&2
  exit 1
fi

echo "Réponse de Vault : $CURL_RESPONSE"

# Extraire le token avec jq
DISCORD_TOKEN=$(echo "$CURL_RESPONSE" | jq -r .data.data.discord_token 2>&1)
if [ $? -ne 0 ] || [ -z "$DISCORD_TOKEN" ]; then
  echo "Erreur : Impossible de récupérer le token Discord depuis Vault : $DISCORD_TOKEN" >&2
  echo "Réponse complète : $CURL_RESPONSE" >&2
  exit 1
fi

echo "Token Discord récupéré avec succès"

# Exporter le token comme variable d'environnement
export DISCORD_TOKEN

# Lancer l'application
echo "Lancement du bot..."
exec /app/gaming_limousin