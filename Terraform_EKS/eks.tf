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

# ADD THIS RULE
resource "aws_security_group_rule" "cluster_self_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1" # Allows all protocols
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.cluster.id
  description              = "Allow cluster components to communicate with each other"
}

resource "aws_eks_cluster" "this" {
  name     = var.project_name
  role_arn = aws_iam_role.cluster.arn
  version  = "1.31" # adjust as needed

  vpc_config {
    endpoint_private_access = false
    endpoint_public_access  = true
    subnet_ids              = concat([for s in aws_subnet.public : s.id], [for s in aws_subnet.private : s.id])
    security_group_ids      = [aws_security_group.cluster.id]
  }

  kubernetes_network_config {
    ip_family = "ipv4"
  }
  depends_on = [
    aws_vpc.this,
    aws_internet_gateway.this,
    aws_nat_gateway.this,
    aws_subnet.public,
    aws_subnet.private,
    aws_route_table.public,
    aws_route_table.private,
    aws_security_group.cluster,
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy
  ]

  tags = var.tags
}

# Fargate Profiles for kube-system and app namespace
# Activate NAT and other config for private subnet 
resource "aws_eks_fargate_profile" "kube_system" {
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "fp-kube-system"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = [for s in aws_subnet.private : s.id]

  selector { namespace = "kube-system" }

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_role_policy_attachment.fargate_AmazonEKSFargatePodExecutionRolePolicy
  ]
}

resource "aws_eks_fargate_profile" "game_ns" {
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "fp-game-2048"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = [for s in aws_subnet.private : s.id]

  selector { namespace = "game-2048" }

  depends_on = [
    aws_eks_cluster.this,
    aws_iam_role_policy_attachment.fargate_AmazonEKSFargatePodExecutionRolePolicy
  ]
}

#adding null resource so that it makes other creation to wait untill cluster readiness - and other cluster resources depends on this
resource "null_resource" "wait_for_cluster" {
  provisioner "local-exec" {
    command = "aws eks wait cluster-active --region ${var.region} --name ${aws_eks_cluster.this.name}"
  }
  depends_on = [aws_eks_cluster.this]
}

# Create an IAM role specifically for the coredns service account
resource "aws_iam_role" "coredns" {
  name = "${var.project_name}-coredns-sa-role"

  # Trust policy that allows the coredns service account in kube-system to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${local.oidc_url}:sub" = "system:serviceaccount:kube-system:coredns",
            "${local.oidc_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Attach the standard EKS CNI policy, which contains the permissions coredns needs for network discovery
resource "aws_iam_role_policy_attachment" "coredns_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.coredns.name
}

# UPDATE your existing aws_eks_addon resource
resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "coredns"

  # ADD THIS LINE to associate the role you just created
  service_account_role_arn = aws_iam_role.coredns.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_fargate_profile.kube_system,
    aws_iam_role.cluster,
    aws_iam_role_policy_attachment.coredns_AmazonEKS_CNI_Policy # Ensure role is ready before addon
  ]
}
