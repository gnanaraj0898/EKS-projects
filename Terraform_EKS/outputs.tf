# 📁 Project layout
# terraform/
# ├─ versions.tf
# ├─ providers.tf
# ├─ variables.tf
# ├─ vpc.tf
# ├─ eks.tf
# ├─ alb_controller.tf
# ├─ app_2048.tf
# ├─ outputs.tf

# outputs.tf

output "cluster_name" { value = aws_eks_cluster.this.name }
output "cluster_endpoint" { value = aws_eks_cluster.this.endpoint }
output "oidc_provider_arn" { value = aws_iam_openid_connect_provider.eks.arn }
output "vpc_id" { value = aws_vpc.this.id }
output "public_subnets" { value = [for s in aws_subnet.public : s.id] }
output "private_subnets" { value = [for s in aws_subnet.private : s.id] }

# Helpful: ALB DNS appears as an annotation on the Ingress once the controller reconciles.
# You can also query with `kubectl -n game-2048 get ingress ingress-2048 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`.


# 🚀 Usage

# 1) Create a `terraform.tfvars` (optional)
# region = "us-east-1"
# project_name = "demo-eks"

# 2) Init, Plan, Apply
# cd terraform
# terraform init
# terraform plan
# terraform apply -auto-approve

# 3) Get kubeconfig (optional; providers already connect in-plan)
# aws eks update-kubeconfig --name demo-eks --region us-east-1
# kubectl get nodes -A
# kubectl get ingress -n game-2048

# 4) Destroy EVERYTHING (no orphans)
# terraform destroy -auto-approve

# Notes
# - Subnets are tagged for ALB discovery; no manual tagging needed.
# - No NAT Gateway to keep costs minimal for Fargate-only labs.
# - If you later add managed node groups, add NAT or use public subnets accordingly.