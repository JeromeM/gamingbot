# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv

# Étape 1 : Construction
FROM rust:1.86-slim-bookworm AS builder

# Installer les dépendances système nécessaires pour Serenity
RUN apt-get update && apt-get install -y \
    libssl-dev \
    pkg-config \
    gcc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copier les fichiers de configuration pour tirer parti du cache
COPY Cargo.toml Cargo.lock ./

# Créer un main.rs vide pour le build initial (cache les dépendances)
RUN mkdir src && echo "fn main() {}" > src/main.rs && cargo build --release

# Copier le reste du projet
COPY src ./src

# Construire le projet en mode release
RUN cargo build --release

# Étape 2 : Image finale
FROM debian:bookworm-slim

# Installer les bibliothèques runtime et outils pour Vault
RUN apt-get update && apt-get install -y \
    libssl3 \
    ca-certificates \
    curl \
    jq \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Créer un utilisateur non-root pour plus de sécurité
RUN useradd -m -u 1000 appuser

WORKDIR /app

# Copier le binaire depuis l'étape de build
COPY --from=builder /app/target/release/gaming_limousin /app/gaming_limousin

# Copier le script d'entrée
COPY scripts/entrypoint.sh /app/entrypoint.sh

# Donner les permissions appropriées
RUN chown appuser:appuser /app/gaming_limousin /app/entrypoint.sh \
    && chmod +x /app/entrypoint.sh

# Passer à l'utilisateur non-root
USER appuser

# Définir les variables d'environnement pour Vault (valeurs par défaut)
ENV VAULT_ADDR="http://127.0.0.1:8200"
ENV VAULT_TOKEN="\${{ secrets.VAULT_TOKEN }}"
ENV RUST_LOG=info

# Utiliser le script d'entrée
ENTRYPOINT ["/app/entrypoint.sh"]