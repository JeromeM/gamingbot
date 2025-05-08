pipeline {
    agent any
    environment {
        VAULT_ADDR = 'http://127.0.0.1:8200'
    }
    triggers {
        githubPush()
    }
    stages {
        stage('Setup') {
            steps {
                sh '''
                    echo "Vérification de l'environnement..."
                    echo "PATH actuel : $PATH"
                    if ! /var/lib/jenkins/.cargo/bin/cargo --version >/dev/null 2>&1; then
                        echo "Erreur : cargo non trouvé à /var/lib/jenkins/.cargo/bin/cargo"
                        exit 1
                    else
                        echo "Cargo trouvé."
                        /var/lib/jenkins/.cargo/bin/cargo --version
                    fi
                '''
            }
        }
        stage('Checkout') {
            steps {
                git branch: 'master', url: 'https://github.com/JeromeM/gamingbot.git'
            }
        }
        stage('Build') {
            steps {
                sh '''
                    /var/lib/jenkins/.cargo/bin/cargo build --release
                    ls -l target/release/gaming_limousin || { echo "Binary gaming_limousin not found"; exit 1; }
                    docker build -t gamingbot:latest --no-cache .
                    echo "Nettoyage de Minikube..."
                    minikube stop || true
                    minikube delete || true
                    echo "Démarrage de Minikube..."
                    minikube start --driver=docker --memory=6144 --cpus=4
                    minikube status || { echo "Minikube failed to start"; exit 1; }
                    minikube ssh -- docker ps -a -q --filter "ancestor=gamingbot:latest" | xargs -r minikube ssh -- docker rm -f
                    minikube ssh -- docker rmi -f gamingbot:latest || true
                    minikube image load gamingbot:latest || { echo "Failed to load image into Minikube"; exit 1; }
                    minikube image ls | grep gamingbot || { echo "Image not found in Minikube"; exit 1; }
                '''
            }
        }
        stage('Test') {
            steps {
                sh '''
                    /var/lib/jenkins/.cargo/bin/cargo test
                    trivy image --severity HIGH,CRITICAL --ignore-unfixed \
                        --skip-files "/usr/local/cargo/registry/src/index.crates.io-1949cf8c6b5b557f/reqwest-0.11.27/src/tls.rs" \
                        --skip-files "/usr/local/cargo/registry/src/index.crates.io-1949cf8c6b5b557f/rustls-pemfile-1.0.4/src/lib.rs" \
                        gamingbot:latest || { echo "Trivy found critical or high vulnerabilities"; exit 1; }
                '''
            }
        }
        stage('Configure') {
            steps {
                sh 'ansible-playbook ansible/setup.yml'
            }
        }
        stage('Monitoring') {
            steps {
                sh '''
                    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
                    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
                    helm repo add grafana https://grafana.github.io/helm-charts
                    helm repo update
                    helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
                        --namespace monitoring \
                        --set grafana.enabled=true \
                        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
                        --create-namespace
                    kubectl get crd servicemonitors.monitoring.coreos.com || { echo "ServiceMonitor CRD not found"; exit 1; }
                '''
            }
        }
        stage('Deploy') {
            steps {
                withVault(
                    configuration: [vaultUrl: env.VAULT_ADDR, vaultCredentialId: 'vault-token'],
                    vaultSecrets: [
                        [path: 'secret/gamingbot', secretValues: [
                            [vaultKey: 'discord_token', envVar: 'DISCORD_TOKEN']
                        ]]
                    ]
                ) {
                    sh 'echo "DISCORD_TOKEN is set to $DISCORD_TOKEN" || { echo "Failed to retrieve DISCORD_TOKEN"; exit 1; }'
                    dir('terraform') {
                        sh 'kubectl delete deployment gamingbot -n gamingbot-namespace || true'
                        sh 'terraform state rm kubernetes_deployment.bot || true'
                        sh 'terraform init'
                        sh 'terraform apply -auto-approve -var="discord_token=${DISCORD_TOKEN}"'
                    }
                }
            }
        }
        stage('Verify') {
            steps {
                sh 'kubectl get pods -n gamingbot-namespace'
            }
        }
    }
}