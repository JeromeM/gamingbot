provider "kubernetes" {
  config_path = "~/.kube/config"
}

variable "discord_token" {
  description = "Discord bot token"
  type        = string
  sensitive   = true
}

resource "kubernetes_namespace" "gamingbot" {
  metadata {
    name = "gamingbot-namespace"
  }
}

resource "kubernetes_deployment" "bot" {
  metadata {
    name      = "gamingbot"
    namespace = kubernetes_namespace.gamingbot.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "gamingbot"
      }
    }
    template {
      metadata {
        labels = {
          app = "gamingbot"
        }
      }
      spec {
        container {
          image = "gamingbot:latest"
          name  = "gamingbot"
          port {
            container_port = 8080
          }
          image_pull_policy = "Never"
          env {
            name = "DISCORD_TOKEN"
            value_from {
              secret_key_ref {
                name = "gamingbot-secrets"
                key  = "discord_token"
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_secret" "bot_secrets" {
  metadata {
    name      = "gamingbot-secrets"
    namespace = kubernetes_namespace.gamingbot.metadata[0].name
  }
  data = {
    discord_token = var.discord_token
  }
}

resource "kubernetes_service" "bot" {
  metadata {
    name      = "gamingbot-service"
    namespace = kubernetes_namespace.gamingbot.metadata[0].name
  }
  spec {
    selector = {
      app = "gamingbot"
    }
    port {
      port        = 80
      target_port = 8080
    }
    type = "ClusterIP"
  }
}

# Monitoring
resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.gamingbot.metadata[0].name
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "prometheus"
      }
    }
    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }
      spec {
        container {
          image = "prom/prometheus:v2.54.1"
          name  = "prometheus"
          port {
            container_port = 9090
          }
          volume_mount {
            name       = "config-volume"
            mount_path = "/etc/prometheus"
          }
        }
        volume {
          name = "config-volume"
          config_map {
            name = "prometheus-config"
          }
        }
      }
    }
  }
}

resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace.gamingbot.metadata[0].name
  }
  data = {
    "prometheus.yml" = <<EOF
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'gamingbot'
    static_configs:
      - targets: ['gamingbot-service:80']
EOF
  }
}

resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus-service"
    namespace = kubernetes_namespace.gamingbot.metadata[0].name
  }
  spec {
    selector = {
      app = "prometheus"
    }
    port {
      port        = 9090
      target_port = 9090
    }
    type = "ClusterIP"
  }
}