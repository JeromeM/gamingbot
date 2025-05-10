#!/bin/bash
# scripts/vault-start.sh

# Afficher l'environnement pour déboguer
echo "Environnement :"
env

# Lancer Vault au premier plan
echo "Démarrage de Vault..."
exec vault server -dev -dev-listen-address=0.0.0.0:8200