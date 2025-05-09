FROM rust:1.86-slim-bookworm

# Installer les dépendances système nécessaires pour serenity
RUN apt-get update && apt-get install -y \
    libssl-dev \
    pkg-config \
    gcc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# Construire le projet avec vérification
RUN cargo build --release \
    && ls -l /app/target/release/gaming_limousin \
    || { echo "Binary gaming_limousin not found"; exit 1; }

EXPOSE 8080
EXPOSE 8091

# Vérifier que le binaire existe avant de démarrer
CMD ["/app/target/release/gaming_limousin"]