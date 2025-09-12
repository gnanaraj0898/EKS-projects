# alb_controller.tf (IRSA + Helm chart)

# OIDC provider for IRSA
data "tls_certificate" "oidc_thumbprint" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc_thumbprint.certificates[0].sha1_fingerprint]
  depends_on = [null_resource.wait_for_cluster]

}

# Download official IAM policy JSON at plan/apply time
# (avoids pasting a huge document here)
data "http" "alb_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.4/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb" {
  name   = "AWSLoadBalancerControllerIAMPolicy_TF"
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
  depends_on = [
    null_resource.wait_for_cluster,
    kubernetes_service_account.alb,
    aws_iam_role_policy_attachment.alb_attach,
    
  ]
  timeout          = 600
  force_update     = true
  recreate_pods    = true
  atomic           = true
  
}

