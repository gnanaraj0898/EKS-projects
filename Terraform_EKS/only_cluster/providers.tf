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
