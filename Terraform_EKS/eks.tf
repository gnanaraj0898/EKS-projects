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

