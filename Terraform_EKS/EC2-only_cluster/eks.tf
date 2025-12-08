# eks.tf (EKS + EC2 managed node group)

#####################
# EKS Cluster Role  #
#####################
resource "aws_iam_role" "cluster" {
  name = "${var.project_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

#########################
# EKS Cluster Security  #
#########################
resource "aws_security_group" "cluster" {
  name        = "${var.project_name}-cluster-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.project_name}-cluster-sg" })
}

# Allow cluster components to talk to each other
resource "aws_security_group_rule" "cluster_self_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.cluster.id
  description              = "Allow cluster components to communicate with each other"
}

#####################
# EKS Cluster       #
#####################
resource "aws_eks_cluster" "this" {
  name     = var.project_name
  role_arn = aws_iam_role.cluster.arn
  version  = "1.31"

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

##################################
# Wait for EKS control-plane     #
##################################
resource "null_resource" "wait_for_cluster" {
  provisioner "local-exec" {
    command = "aws eks wait cluster-active --region ${var.region} --name ${aws_eks_cluster.this.name}"
  }
  depends_on = [aws_eks_cluster.this]
}

############################################
# OIDC for IRSA (used by ALB controller)   #
############################################
data "tls_certificate" "oidc_thumbprint" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc_thumbprint.certificates[0].sha1_fingerprint]

  depends_on = [null_resource.wait_for_cluster]
}

locals {
  oidc_arn = aws_iam_openid_connect_provider.eks.arn
  oidc_url = replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

############################################
# EKS add-ons (install BEFORE nodes)       #
############################################
# VPC CNI add-on
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                 = aws_eks_cluster.this.name
  addon_name                   = "vpc-cni"
  resolve_conflicts_on_create  = "OVERWRITE"
  resolve_conflicts_on_update  = "OVERWRITE"

  # Using node role permissions for CNI (policy attached to node IAM role).
  depends_on = [null_resource.wait_for_cluster]
}

# kube-proxy add-on
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                 = aws_eks_cluster.this.name
  addon_name                   = "kube-proxy"
  resolve_conflicts_on_create  = "OVERWRITE"
  resolve_conflicts_on_update  = "OVERWRITE"

  depends_on = [null_resource.wait_for_cluster]
}

# CoreDNS add-on (no IAM role needed)
resource "aws_eks_addon" "coredns" {
  cluster_name                 = aws_eks_cluster.this.name
  addon_name                   = "coredns"
  resolve_conflicts_on_create  = "OVERWRITE"
  resolve_conflicts_on_update  = "OVERWRITE"

  depends_on = [
    null_resource.wait_for_cluster
  ]
}

############################################
# Node IAM role for Managed Node Group     #
############################################
resource "aws_iam_role" "node" {
  name = "${var.project_name}-node-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# Required managed policies for node role
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Grant CNI permissions via node role (simple & compatible)
resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Grant CNI permissions via node role (simple & compatible)
resource "aws_iam_role_policy_attachment" "node_AmazonEBS_CSI_DriverPolicy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

############################################
# Managed Node Group on private subnets    #
############################################
resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [for s in aws_subnet.private : s.id]

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  instance_types = var.node_instance_types
  capacity_type  = var.node_capacity_type
  disk_size      = var.node_disk_size
  ami_type       = var.node_ami_type

  labels = {
    workload = "general"
  }

  tags = var.tags

  # Ensure CNI/kube-proxy add-ons and IAM are ready before nodes join
  depends_on = [
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly
  ]
}
