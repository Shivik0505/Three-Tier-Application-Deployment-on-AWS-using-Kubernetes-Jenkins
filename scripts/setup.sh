#!/bin/bash
# =============================================================================
# Three-Tier K8s Deployment - Setup & Run Script
# Usage: ./scripts/setup.sh
# =============================================================================

set -e

AWS_REGION="ap-south-1"
CLUSTER_NAME="three-tier-cluster"
NAMESPACE="three-tier"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ─── STEP 1: Check prerequisites ─────────────────────────────────────────────
info "Checking prerequisites..."
for cmd in aws kubectl terraform git docker; do
  command -v $cmd &>/dev/null || error "$cmd not found. Please install it."
done
info "All tools found ✓"

# ─── STEP 2: Provision VPC ───────────────────────────────────────────────────
info "Provisioning VPC, Subnets, Security Groups, Jenkins EC2..."
cd terraform/vpc
terraform init -input=false
terraform apply -auto-approve \
  -var="my_ip=$(curl -s https://checkip.amazonaws.com)/32" \
  -var="key_pair_name=${KEY_PAIR_NAME:-my-key}"
cd ../..

# ─── STEP 3: Provision EKS ───────────────────────────────────────────────────
info "Provisioning EKS Cluster + Node Group + ECR..."
cd terraform/eks
terraform init -input=false
terraform apply -auto-approve
cd ../..

# ─── STEP 4: Provision RDS ───────────────────────────────────────────────────
info "Provisioning RDS MySQL..."
cd terraform/rds
terraform init -input=false
terraform apply -auto-approve \
  -var="db_password=${DB_PASSWORD:-ChangeMe123!}"
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
cd ../..

# ─── STEP 5: Configure kubectl ───────────────────────────────────────────────
info "Configuring kubectl for EKS..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION

# ─── STEP 6: Create K8s Secret from RDS ─────────────────────────────────────
info "Creating namespace and RDS secret in K8s..."
kubectl apply -f k8s/namespace.yaml

kubectl create secret generic rds-secret \
  --namespace=$NAMESPACE \
  --from-literal=host="$RDS_ENDPOINT" \
  --from-literal=username="admin" \
  --from-literal=password="${DB_PASSWORD:-ChangeMe123!}" \
  --from-literal=dbname="three_tier_db" \
  --dry-run=client -o yaml | kubectl apply -f -

# ─── STEP 7: Deploy to K8s ───────────────────────────────────────────────────
info "Deploying application to K8s..."
kubectl apply -f k8s/database/
kubectl apply -f k8s/backend/
kubectl apply -f k8s/frontend/
kubectl apply -f k8s/ingress/

# ─── STEP 8: Wait and Verify ─────────────────────────────────────────────────
info "Waiting for deployments to be ready..."
kubectl rollout status deployment/frontend -n $NAMESPACE --timeout=120s
kubectl rollout status deployment/backend  -n $NAMESPACE --timeout=120s

echo ""
info "=== DEPLOYMENT COMPLETE ==="
kubectl get pods    -n $NAMESPACE
kubectl get svc     -n $NAMESPACE
kubectl get ingress -n $NAMESPACE
echo ""
info "Jenkins URL: http://$(cd terraform/vpc && terraform output -raw jenkins_public_ip):8080"
info "ALB DNS: $(kubectl get ingress three-tier-ingress -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo 'pending...')"
