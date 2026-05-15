# EKS Deployment Guide — portfoliod

Full implementation: Terraform → Docker → EKS → Helm → GitHub Actions

---

## Prerequisites

```powershell
aws --version          # AWS CLI configured with your account
terraform --version    # v1.3+
helm version           # v3+
kubectl version --client
docker --version
```

---

## Phase 1 — Add files to your repo

Copy these files into your `portfoliod` repo root:

```
portfoliod/
├── Dockerfile
├── nginx.conf
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── helm/portfoliod/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── deployment.yaml
│       └── service-ingress.yaml
└── .github/workflows/
    └── deploy.yml
```

Commit and push everything:
```powershell
git add .
git commit -m "feat: add Dockerfile, Terraform, Helm, and GitHub Actions"
git push
```

---

## Phase 2 — Build EKS cluster with Terraform

```powershell
cd terraform

terraform init
terraform plan
terraform apply
```

This takes **10-15 minutes** — EKS cluster creation is slow. When done, note the outputs:
- `cluster_name`
- `github_deploy_role_arn` ← you need this for GitHub Secrets

---

## Phase 3 — Connect kubectl to EKS

```powershell
aws eks update-kubeconfig \
  --name portfoliod-cluster \
  --region eu-west-2

# Verify
kubectl get nodes
```

You should see 2 nodes with STATUS = Ready.

---

## Phase 4 — Build and push Docker image manually (first time)

```powershell
cd ..  # back to repo root

# Log in to DockerHub
docker login

# Build
docker build -t hugdora/portfoliod:latest .

# Push
docker push hugdora/portfoliod:latest
```

---

## Phase 5 — Install NGINX Ingress on EKS

```powershell
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer

# Wait for load balancer to get an external IP (~2 minutes)
kubectl get service -n ingress-nginx ingress-nginx-controller -w
```

Note the EXTERNAL-IP — this is your app's public address.

---

## Phase 6 — Deploy with Helm

```powershell
helm upgrade --install portfoliod ./helm/portfoliod

# Watch pods come up
kubectl get pods -w

# Check all resources
kubectl get pods,service,ingress
```

---

## Phase 7 — Add GitHub Secrets

Go to: github.com/hugdora/portfoliod → Settings → Secrets → Actions

Add these 3 secrets:

| Secret name | Value |
|---|---|
| `DOCKERHUB_USERNAME` | `hugdora` |
| `DOCKERHUB_TOKEN` | Your DockerHub access token (not password) |
| `AWS_ROLE_ARN_EKS` | ARN from terraform output `github_deploy_role_arn` |

**Get DockerHub token:**
DockerHub → Account Settings → Security → New Access Token

---

## Phase 8 — Test automated pipeline

Make a small change to `index.html` (e.g. add a comment), push to main:

```powershell
git add index.html
git commit -m "test: trigger automated pipeline"
git push
```

Watch the Actions tab — Build then Deploy should both go green.

---

## Phase 9 — Take screenshots for portfolio

```powershell
# Pods running on EKS
kubectl get pods -o wide

# All resources
kubectl get all

# Node details (shows EC2 instances)
kubectl get nodes -o wide

# Helm release
helm list

# Ingress with LoadBalancer address
kubectl get ingress

# Describe pod to show probes
kubectl describe pod -l app=portfoliod
```

Also screenshot:
- AWS Console → EKS → portfoliod-cluster → Nodes (shows EC2)
- AWS Console → EC2 → Load Balancers (shows the NLB)
- GitHub Actions → green workflow run
- The live app in browser via LoadBalancer URL

---

## Phase 10 — Teardown (IMPORTANT — do this within 2 days)

```powershell
# Remove Kubernetes resources first
helm uninstall portfoliod
helm uninstall ingress-nginx -n ingress-nginx

# Destroy all AWS infrastructure
cd terraform
terraform destroy
```

Type `yes` when prompted. This deletes:
- EKS cluster + node group (EC2 instances)
- NAT Gateway (biggest cost)
- VPC, subnets, IGW
- All IAM roles

Verify in AWS Console that no EKS clusters or NAT Gateways remain.

---

## Cost estimate for 2 days

| Resource | 48hrs cost |
|---|---|
| EKS cluster | ~$5 |
| t3.small × 2 nodes | ~$3 |
| NAT Gateway | ~$3 |
| Load Balancer | ~$2 |
| **Total** | **~$13** |
