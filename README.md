# Infrastructure & Configuration Management

End-to-end IaC + CI/CD pipeline with blue-green deployment: Terraform provisions the infrastructure, Ansible configures it, Docker Compose runs the application in production, Kubernetes orchestrates blue-green deployments locally, GitHub Actions automates everything.

## Stack

| Tool | Role |
|------|------|
| **Terraform** | Provision EC2 instance, Security Group, Key Pair |
| **Ansible** | Install Docker, deploy containers on the server |
| **Docker / Compose** | Containerized Node.js API + MongoDB + Nginx (production) |
| **Kubernetes (minikube)** | Blue-green deployment orchestration (local) |
| **GitHub Actions** | Build image → push Docker Hub → deploy to server |

## Architecture

### Production (Docker Compose)
```
GitHub push (main)
  └── GitHub Actions
        ├── Build multi-stage Docker image (git SHA tag)
        ├── Push to Docker Hub
        └── SSH into EC2
              └── docker compose pull && up -d

EC2 (AWS)
  └── Nginx :80  ← reverse proxy
        └── todo-api:3000
              └── MongoDB (internal network, no external port)
```

### Blue-Green (Kubernetes / minikube)
```
./scripts/blue-green-switch.sh dogukanc760/todo-api:v2
  ├── Detect active slot (blue|green)
  ├── Set new image on standby deployment
  ├── Scale up standby (replicas: 2)
  ├── Wait for rollout + /health check
  ├── kubectl patch service → switch traffic
  └── Scale down old deployment (replicas: 0)

minikube
  └── Ingress (todo.local)
        └── Service (selector: version: blue|green)
              ├── Deployment todo-api-blue  (replicas: 2 or 0)
              └── Deployment todo-api-green (replicas: 2 or 0)
                    └── MongoDB StatefulSet + PVC
```

## Project Structure

```
.
├── .github/workflows/
│   └── deploy.yml              # CI/CD pipeline
├── k8s/
│   ├── namespace.yaml
│   ├── secret.yaml
│   ├── configmap.yaml
│   ├── ingress.yaml
│   ├── mongo/
│   │   ├── statefulset.yaml    # PVC + liveness/readiness probes
│   │   └── service.yaml        # Headless ClusterIP
│   └── api/
│       ├── deployment-blue.yaml
│       ├── deployment-green.yaml
│       └── service.yaml        # Label selector switch
├── scripts/
│   └── blue-green-switch.sh    # Zero-downtime deploy + auto rollback
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── nodejs-api/
│   ├── src/
│   │   ├── app.js              # /health endpoint dahil
│   │   ├── models/Todo.js
│   │   └── routes/todos.js
│   ├── Dockerfile              # Multi-stage, non-root user
│   ├── .dockerignore
│   └── package.json
├── nginx/
│   └── nginx.conf              # Reverse proxy + X-Forwarded headers
├── roles/
│   ├── base/
│   ├── nginx/
│   ├── app/
│   ├── ssh/
│   └── docker/                 # Docker install + compose deploy
├── docker-compose.yml
├── .env.example
├── inventory.ini
└── setup.yml
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Service health + DB connection state |
| GET | `/todos` | List all todos |
| POST | `/todos` | Create a todo |
| GET | `/todos/:id` | Get a single todo |
| PUT | `/todos/:id` | Update a todo |
| DELETE | `/todos/:id` | Delete a todo |

## Requirements

- Terraform >= 1.0
- Ansible >= 2.12
- Docker & Docker Compose plugin
- minikube + kubectl
- AWS credentials (`~/.aws/credentials`)
- Docker Hub account

## Local Development (Docker Compose)

```bash
cp .env.example .env
# .env içindeki değerleri doldur

docker compose up --build
# http://localhost → nginx üzerinden API
```

## Blue-Green Deployment (Kubernetes)

```bash
# Cluster başlat
minikube start
minikube addons enable ingress

# /etc/hosts'a ekle (bir kere)
echo "$(minikube ip) todo.local" | sudo tee -a /etc/hosts

# Tüm kaynakları deploy et
kubectl apply -f k8s/

# Blue-green switch (image tag değiştirerek yeni versiyon deploy et)
./scripts/blue-green-switch.sh dogukanc760/todo-api:v2

# http://todo.local/todos
```

Script otomatik olarak:
1. Aktif slot'u tespit eder (blue/green)
2. Yeni image'ı pasif deployment'a set eder
3. Rollout tamamlanana kadar bekler
4. `/health` endpoint'ini poll eder
5. Traffic'i switch eder (`kubectl patch service`)
6. Herhangi bir adımda hata → otomatik rollback

## Infrastructure Provisioning

```bash
cd terraform
terraform init
terraform apply
# output: public DNS → inventory.ini'ye yapıştır
```

## Server Configuration

```bash
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini setup.yml
# sadece docker role:
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini setup.yml --tags docker
```

## CI/CD

`main` branch'e her push'ta GitHub Actions otomatik olarak:
1. Multi-stage Docker image build eder (git SHA tag)
2. Docker Hub'a push eder
3. EC2'ye SSH bağlanır, `docker compose pull && up -d` çalıştırır

GitHub Secrets:

| Secret | Description |
|--------|-------------|
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `SERVER_HOST` | EC2 public IP or DNS |
| `SSH_PRIVATE_KEY` | config-manager.pem contents |

## Teardown

```bash
# Docker Compose
docker compose down -v

# Kubernetes
kubectl delete namespace todo

# AWS infrastructure
cd terraform && terraform destroy
```
- `become: yes` is set at playbook level for privilege escalation

