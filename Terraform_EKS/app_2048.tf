# app_2048.tf (Namespace + Deployment + Service + Ingress)

resource "kubernetes_namespace" "game" {
  metadata {
    name = "game-2048"
  }
}

resource "kubernetes_deployment" "game" {
  metadata {
    # YAML: name: deployment-2048, namespace: game-2048
    name      = "deployment-2048-v2"
    namespace = kubernetes_namespace.game.metadata[0].name
    # (Optional) You can add labels here, but YAML doesn't define deployment-level labels.
  }

  spec {
    # YAML: replicas: 5
    replicas = 5

    # YAML selector: matchLabels: app.kubernetes.io/name: app-2048
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "app-2048"
      }
    }

    template {
      metadata {
        # YAML template labels
        labels = {
          "app.kubernetes.io/name" = "app-2048"
        }
      }
      spec {
        container {
          # YAML container fields
          name               = "app-2048"
          image              = "public.ecr.aws/l6m2t8p7/docker-2048:latest"
          image_pull_policy  = "Always"

          port {
            container_port = 80
          }
        }
      }
    }
  }

  depends_on = [null_resource.wait_for_cluster, aws_eks_fargate_profile.game_ns]
}

resource "kubernetes_service" "game" {
  metadata {
    name      = "service-2048"
    namespace = kubernetes_namespace.game.metadata[0].name
    # YAML service metadata has no labels; leaving them out for alignment.
    labels = {
      app = "app-2048"
    }

  }

  spec {
    # YAML: type: ClusterIP
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name" = "app-2048"
    }

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
      # node_port not specified in YAML, so let Kubernetes auto-assign.
    }
  }
  depends_on = [null_resource.wait_for_cluster, aws_eks_fargate_profile.game_ns]
}

resource "kubernetes_ingress_v1" "game" {
  metadata {
    name      = "ingress-2048"
    namespace = kubernetes_namespace.game.metadata[0].name

    annotations = {
      # YAML annotations
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      # Removed group.name to align with YAML
    }
  }

  spec {
    # YAML: spec.ingressClassName: alb (not the legacy annotation)
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.game.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
  depends_on = [null_resource.wait_for_cluster, aws_eks_fargate_profile.game_ns, helm_release.alb]
}

