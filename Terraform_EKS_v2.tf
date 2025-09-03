# 📁 Project layout

```
terraform/
├─ versions.tf
├─ providers.tf
├─ variables.tf
├─ vpc.tf
├─ eks.tf
├─ alb_controller.tf
├─ app_2048.tf
├─ outputs.tf
```

---

# versions.tf

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.13"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}

---

# variables.tf

variable "region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Name used for tagging and cluster naming"
  default     = "demo-eks"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 2
}

variable "tags" {
  type = map(string)
  default = {
    Project     = "demo-eks"
    ManagedBy   = "terraform"
    CostCenter  = "eks-labs"
    AutoDelete  = "true" # optional convention for cleanup tooling
  }
}

---

# providers.tf

provider "aws" {
  region = var.region
}

# Grab cluster connection details once created
data "aws_eks_cluster" "this" {
  depends_on = [aws_eks_cluster.this]
  name       = aws_eks_cluster.this.name
}

data "aws_eks_cluster_auth" "this" {
  depends_on = [aws_eks_cluster.this]
  name       = aws_eks_cluster.this.name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

---

# vpc.tf

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.project_name}-igw" })
}

# Create public + private subnets across AZs
resource "aws_subnet" "public" {
  for_each          = { for idx, az in local.azs : idx => az }
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, each.key)
  availability_zone = each.value
  map_public_ip_on_launch = true
  tags = merge(var.tags, {
    Name = "${var.project_name}-public-${each.value}"
    "kubernetes.io/role/elb" = 1
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  })
}

resource "aws_subnet" "private" {
  for_each          = { for idx, az in local.azs : idx => az }
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, each.key + 8)
  availability_zone = each.value
  tags = merge(var.tags, {
    Name = "${var.project_name}-private-${each.value}"
    "kubernetes.io/role/internal-elb" = 1
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.project_name}-public-rt" })
}

resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# (Optional) NAT Gateway for private subnets if you add node groups later
# Skipped for pure Fargate to avoid costs.

---

# eks.tf (EKS + Fargate-only control plane)

resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "fargate" {
  name = "${var.project_name}-fargate-pod-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "eks-fargate-pods.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "fargate_AmazonEKSFargatePodExecutionRolePolicy" {
  role       = aws_iam_role.fargate.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

resource "aws_security_group" "cluster" {
  name        = "${var.project_name}-cluster-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.project_name}-cluster-sg" })
}

resource "aws_eks_cluster" "this" {
  name     = var.project_name
  role_arn = aws_iam_role.cluster.arn
  version  = "1.31 " # adjust as needed

  vpc_config {
    endpoint_private_access = false
    endpoint_public_access  = true
    subnet_ids              = concat([for s in aws_subnet.public : s.id], [for s in aws_subnet.private : s.id])
    security_group_ids      = [aws_security_group.cluster.id]
  }

  kubernetes_network_config {
    ip_family = "ipv4"
  }

  tags = var.tags
}

# Fargate Profiles for kube-system and app namespace
resource "aws_eks_fargate_profile" "kube_system" {
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "fp-kube-system"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = [for s in aws_subnet.private : s.id]

  selector { namespace = "kube-system" }

  depends_on = [aws_eks_cluster.this]
}

resource "aws_eks_fargate_profile" "game_ns" {
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "fp-game-2048"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = [for s in aws_subnet.private : s.id]

  selector { namespace = "game-2048" }

  depends_on = [aws_eks_cluster.this]
}

---

# alb_controller.tf (IRSA + Helm chart)

# OIDC provider for IRSA
resource "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.aws_eks_cluster.this.identity[0].oidc[0].thumbprint
  ]
}

# Download official IAM policy JSON at plan/apply time
# (avoids pasting a huge document here)
data "http" "alb_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.4/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = data.http.alb_controller_policy.response_body
}

# Trust policy for service account (IRSA)
locals {
  oidc_arn  = aws_iam_openid_connect_provider.eks.arn
  oidc_url  = replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

resource "aws_iam_role" "alb_sa" {
  name = "AmazonEKSLoadBalancerControllerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${local.oidc_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller",
          "${local.oidc_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_sa.name
  policy_arn = aws_iam_policy.alb.arn
}

# Install the Helm chart using pre-created IRSA service account
resource "kubernetes_service_account" "alb" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_sa.arn
    }
    labels = { app = "aws-load-balancer-controller" }
  }
  automount_service_account_token = true
}

resource "helm_release" "alb" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  version = "1.10.0" # compatible with controller v2.11.x

  values = [
    yamlencode({
      clusterName = aws_eks_cluster.this.name
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.alb.metadata[0].name
      }
      region = var.region
      vpcId  = aws_vpc.this.id
    })
  ]

  depends_on = [kubernetes_service_account.alb]
}

---

# app_2048.tf (Namespace + Deployment + Service + Ingress)

resource "kubernetes_namespace" "game" {
  metadata { name = "game-2048" }
}

resource "kubernetes_deployment" "game" {
  metadata {
    name      = "game-2048"
    namespace = kubernetes_namespace.game.metadata[0].name
    labels    = { app = "game-2048" }
  }
  spec {
    replicas = 1
    selector { match_labels = { app = "game-2048" } }
    template {
      metadata { labels = { app = "game-2048" } }
      spec {
        container {
          name  = "game-2048"
          image = "public.ecr.aws/eks-distro/kubernetes-sigs/aws-load-balancer-controller/samples:2048"
          port { container_port = 80 }
        }
      }
    }
  }
  depends_on = [aws_eks_fargate_profile.game_ns]
}

resource "kubernetes_service" "game" {
  metadata {
    name      = "service-2048"
    namespace = kubernetes_namespace.game.metadata[0].name
    labels    = { app = "game-2048" }
  }
  spec {
    selector = { app = "game-2048" }
    port { port = 80 target_port = 80 }
  }
}

resource "kubernetes_ingress_v1" "game" {
  metadata {
    name      = "ingress-2048"
    namespace = kubernetes_namespace.game.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                 = "alb"
      "alb.ingress.kubernetes.io/scheme"            = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"       = "ip"
      "alb.ingress.kubernetes.io/group.name"        = var.project_name
    }
  }
  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service { name = kubernetes_service.game.metadata[0].name port { number = 80 } }
          }
        }
      }
    }
  }

  depends_on = [helm_release.alb]
}

---

# outputs.tf

output "cluster_name" { value = aws_eks_cluster.this.name }
output "cluster_endpoint" { value = aws_eks_cluster.this.endpoint }
output "oidc_provider_arn" { value = aws_iam_openid_connect_provider.eks.arn }
output "vpc_id" { value = aws_vpc.this.id }
output "public_subnets" { value = [for s in aws_subnet.public : s.id] }
output "private_subnets" { value = [for s in aws_subnet.private : s.id] }

# Helpful: ALB DNS appears as an annotation on the Ingress once the controller reconciles.
# You can also query with `kubectl -n game-2048 get ingress ingress-2048 -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`.

---

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
