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
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
