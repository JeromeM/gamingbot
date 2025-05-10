#!/bin/bash
# scripts/vault-init.sh

# Afficher l'environnement pour déboguer
echo "Environnement :"
env

# Attendre que Vault soit prêt
MAX_ATTEMPTS=30
ATTEMPT=0
until wget -q -O - http://vault:8200/v1/sys/health | grep -q '"sealed":false'; do
  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "Erreur : Vault n'est pas prêt après $MAX_ATTEMPTS tentatives" >&2
    exit 1
  fi
  echo "Attente que Vault soit prêt... (tentative $((ATTEMPT+1))/$MAX_ATTEMPTS)"
  sleep 2
  ATTEMPT=$((ATTEMPT+1))
done

echo "Vault est prêt !"

# Stocker le token Discord dans Vault
echo "Envoi de la requête POST pour stocker le token Discord..."
wget -q -S --post-data="{\"data\": {\"discord_token\": \"$DISCORD_TOKEN\"}}" \
  --header="X-Vault-Token: $VAULT_TOKEN" \
  -O response.txt http://vault:8200/v1/secret/data/gamingbot 2> headers.txt

# Extraire le code HTTP depuis headers.txt
HTTP_CODE=$(grep "HTTP/" headers.txt | awk '{print $2}')
RESPONSE=$(cat response.txt)
echo "Code HTTP : $HTTP_CODE"
echo "Réponse complète : $RESPONSE"

if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "204" ]; then
  echo "Erreur : Échec de l'ajout du token Discord dans Vault (code HTTP: $HTTP_CODE)" >&2
  cat headers.txt >&2
  exit 1
fi

echo "Token Discord stocké dans Vault avec succès"

# Nettoyer les fichiers temporaires
rm -f response.txt headers.txt