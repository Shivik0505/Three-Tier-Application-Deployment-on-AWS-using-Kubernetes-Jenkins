# Three-Tier-Application-Deployment-on-AWS-using-Kubernetes-Jenkins
# Three-Tier Application Deployment on AWS using Kubernetes & Jenkins

![Architecture](./architecture.png)

A production-ready three-tier application deployment on AWS using **EKS (Kubernetes)**, **Jenkins CI/CD**, **Terraform** (infrastructure as code), and **Amazon ECR** (container registry). The stack provisions a full VPC, EKS cluster, RDS database, and deploys a React frontend + Go/Node.js backend via an automated Jenkins pipeline.

---

## Architecture Overview

```
Developer → GitHub → Jenkins CI/CD
                          │
                    ┌─────▼──────┐
                    │  AWS ECR   │  (Docker Images)
                    └─────┬──────┘
                          │ pull images
                    ┌─────▼──────────────────────────────────┐
                    │           AWS Cloud (ap-south-1)        │
                    │  ┌─────────────────────────────────┐   │
                    │  │           AWS VPC                │   │
                    │  │  ┌──────────────────────────┐   │   │
                    │  │  │  Public Subnet            │   │   │
                    │  │  │  Internet → ALB           │   │   │
                    │  │  └────────────┬──────────────┘   │   │
                    │  │  ┌────────────▼──────────────┐   │   │
                    │  │  │  Private Subnet (EKS)      │   │   │
                    │  │  │  Frontend Pods (React)     │   │   │
                    │  │  │  Backend Pods  (Go/Node)   │   │   │
                    │  │  └────────────┬──────────────┘   │   │
                    │  │  ┌────────────▼──────────────┐   │   │
                    │  │  │  Data Subnet               │   │   │
                    │  │  │  AWS RDS (MySQL/PostgreSQL) │   │   │
                    │  │  └───────────────────────────┘   │   │
                    │  └─────────────────────────────────┘   │
                    └─────────────────────────────────────────┘
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | React (Nginx), port 80 |
| Backend | Go / Node.js, port 8080 |
| Database | AWS RDS (MySQL / PostgreSQL) |
| Container Orchestration | Amazon EKS (Kubernetes) |
| CI/CD | Jenkins |
| Container Registry | Amazon ECR |
| Infrastructure | Terraform |
| Ingress | AWS ALB via Kubernetes Ingress |
| Region | `ap-south-1` (Mumbai) |

---

## Repository Structure

```
.
├── jenkins/
│   └── Jenkinsfile           ← CI/CD pipeline definition
├── k8s/
│   ├── namespace.yaml        ← Kubernetes namespace (three-tier)
│   ├── frontend/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── backend/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── configmap.yaml
│   ├── database/
│   │   ├── configmap.yaml
│   │   ├── db-init-job.yaml
│   │   └── secret.yaml       ← gitignored — never commit real secrets
│   └── ingress/
│       └── ingress.yaml
├── terraform/
│   ├── vpc/                  ← VPC, Subnets, IGW, NAT Gateway, Jenkins EC2
│   ├── eks/                  ← EKS Cluster, Node Groups, IAM Roles, ECR
│   └── rds/                  ← RDS Instance, Subnet Group, Parameter Group
├── scripts/
│   └── setup.sh              ← One-shot provisioning & deploy script
├── architecture.png
└── README.md
```

---

## Prerequisites

Make sure the following tools are installed and configured:

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) — configured with appropriate IAM permissions
- [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.3`
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Docker](https://docs.docker.com/get-docker/)
- [Git](https://git-scm.com/)
- An EC2 key pair in `ap-south-1`

---

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/Shivik0505/Three-Tier-Application-Deployment-on-AWS-using-Kubernetes-Jenkins.git
cd Three-Tier-Application-Deployment-on-AWS-using-Kubernetes-Jenkins
```

### 2. Run the automated setup script

```bash
export KEY_PAIR_NAME=your-key-pair-name
export DB_PASSWORD=YourSecurePassword123!

chmod +x scripts/setup.sh
./scripts/setup.sh
```

This script will:
1. Provision the VPC, subnets, security groups, and Jenkins EC2 instance
2. Provision the EKS cluster, node groups, and ECR repositories
3. Provision the RDS MySQL instance
4. Configure `kubectl` to connect to EKS
5. Create the Kubernetes namespace and RDS secret
6. Deploy all Kubernetes manifests (database, backend, frontend, ingress)
7. Wait for rollout and print the Jenkins URL + ALB DNS

---

## Jenkins Pipeline

The pipeline (`jenkins/Jenkinsfile`) runs the following stages automatically on every push to `main`:

| Stage | Description |
|-------|-------------|
| 1. Checkout | Clone repo from GitHub |
| 2. Test | Run frontend (`npm test`) and backend (`go test`) in parallel |
| 3. Docker Build | Build frontend and backend Docker images |
| 4. Push to ECR | Push images with `:latest` and `:<BUILD_NUMBER>` tags |
| 5. Update Manifests | Patch K8s deployment YAML with the new image tags |
| 6. Deploy to EKS | `kubectl apply` all manifests to the cluster |
| 7. Verify | Check pod, service, and ingress status |

### Jenkins Setup

1. Navigate to `http://<jenkins_public_ip>:8080`
2. Add the following credentials in Jenkins:
   - `aws-account-id` — your AWS account ID (Secret text)
   - `aws-credentials` — AWS Access Key + Secret Key (AWS credentials)
3. Create a pipeline job pointing to this repo's `jenkins/Jenkinsfile`

---

## Infrastructure (Terraform)

Each Terraform module is independently applied by the setup script.

### VPC (`terraform/vpc/`)
- VPC with public, private, and data subnets
- Internet Gateway + NAT Gateway
- Security groups for Jenkins EC2, EKS nodes, and RDS
- Jenkins EC2 instance (public subnet)

### EKS (`terraform/eks/`)
- EKS cluster (`three-tier-cluster`)
- Managed node group with auto-scaling
- IAM roles for the cluster and worker nodes
- ECR repositories for frontend and backend images

### RDS (`terraform/rds/`)
- RDS MySQL / PostgreSQL instance (private data subnet)
- DB subnet group and parameter group
- Output: `rds_endpoint` used by the setup script to create the K8s secret

---

## Kubernetes Resources

| Resource | Details |
|----------|---------|
| Namespace | `three-tier` |
| Frontend Deployment | React/Nginx, 2 replicas, port 80 |
| Backend Deployment | Go/Node.js, 2 replicas, port 8080 |
| Frontend Service | ClusterIP, port 80 |
| Backend Service | ClusterIP, port 8080 |
| Ingress | `/` → frontend, `/api` → backend (AWS ALB) |
| ConfigMap | `app-config` — backend URL, DB config |
| Secret | `rds-secret` — DB host, user, password (created by setup script) |

---

## Secrets Management

Sensitive values are **never committed** to the repository (enforced via `.gitignore`):
- `k8s/database/secret.yaml` — gitignored
- `*.pem`, `*.key`, `.env` — gitignored
- `*.tfvars` / `*.tfstate` — gitignored

The RDS secret is created at runtime by `setup.sh` using `kubectl create secret`.

---

## Cleanup

To tear down all provisioned infrastructure:

```bash
# Delete K8s resources
kubectl delete namespace three-tier

# Destroy Terraform (in reverse order)
cd terraform/rds && terraform destroy -auto-approve
cd ../eks && terraform destroy -auto-approve
cd ../vpc && terraform destroy -auto-approve
```

---

## Interactive Architecture Diagram

View the full draw.io architecture diagram:

[![Open in draw.io](https://img.shields.io/badge/Open%20in-draw.io-orange?logo=diagramsdotnet)](https://app.diagrams.net/#Uhttps://raw.githubusercontent.com/Shivik0505/three-tier-diagram/main/architecture.drawio)

---

## License

This project is open source and available under the [MIT License](LICENSE).
