#-----------------------------------------------------------------------------------------
# JupyterHub Single User IRSA, maybe that block could be incorporated in add-on registry
#-----------------------------------------------------------------------------------------
resource "kubernetes_namespace" "jupyterhub" {
  count = var.enable_jupyterhub ? 1 : 0
  metadata {
    name = "jupyterhub"
  }
}

module "jupyterhub_single_user_irsa" {
  count   = var.enable_jupyterhub ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.2"

  name = "${module.eks.cluster_name}-jupyterhub-single-user-sa"

  policies = {
    policy = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess" # Policy needs to be defined based in what you need to give access to your notebook instances.
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${kubernetes_namespace.jupyterhub[count.index].metadata[0].name}:jupyterhub-single-user"]
    }
  }
}

resource "kubernetes_service_account_v1" "jupyterhub_single_user_sa" {
  count = var.enable_jupyterhub ? 1 : 0
  metadata {
    name        = "${module.eks.cluster_name}-jupyterhub-single-user"
    namespace   = kubernetes_namespace.jupyterhub[count.index].metadata[0].name
    annotations = { "eks.amazonaws.com/role-arn" : module.jupyterhub_single_user_irsa[0].name }
  }

  automount_service_account_token = true
}

resource "kubernetes_secret_v1" "jupyterhub_single_user" {
  count = var.enable_jupyterhub ? 1 : 0
  metadata {
    name      = "${module.eks.cluster_name}-jupyterhub-single-user-secret"
    namespace = kubernetes_namespace.jupyterhub[count.index].metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name"      = kubernetes_service_account_v1.jupyterhub_single_user_sa[count.index].metadata[0].name
      "kubernetes.io/service-account.namespace" = kubernetes_namespace.jupyterhub[count.index].metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

#---------------------------------------
# EFS Configuration
#---------------------------------------
resource "aws_efs_access_point" "efs_persist_ap" {
  count          = var.enable_jupyterhub ? 1 : 0
  file_system_id = module.efs[0].id
  posix_user {
    gid            = 0
    uid            = 0
    secondary_gids = [100]
  }
  root_directory {
    path = "/home"
    creation_info {
      owner_gid   = 0
      owner_uid   = 0
      permissions = 700
    }
  }
  depends_on = [module.efs]
}
resource "aws_efs_access_point" "efs_shared_ap" {
  count          = var.enable_jupyterhub ? 1 : 0
  file_system_id = module.efs[0].id
  posix_user {
    gid            = 0
    uid            = 0
    secondary_gids = [100]
  }
  root_directory {
    path = "/shared"
    creation_info {
      owner_gid   = 0
      owner_uid   = 0
      permissions = 700
    }
  }
  depends_on = [module.efs]
}

module "efs_config" {
  count   = var.enable_jupyterhub ? 1 : 0
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.20"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  helm_releases = {
    efs = {
      name             = "efs"
      description      = "A Helm chart for storage configurations"
      namespace        = "jupyterhub"
      create_namespace = false
      chart            = "${path.module}/helm-values/efs"
      chart_version    = "0.0.1"
      values = [
        <<-EOT
          pv:
            name: efs-persist
            volumeHandle: ${module.efs[0].id}::${aws_efs_access_point.efs_persist_ap[count.index].id}
          pvc:
            name: efs-persist
        EOT
      ]
    }
    efs-shared = {
      name             = "efs-shared"
      description      = "A Helm chart for shared storage configurations"
      namespace        = "jupyterhub"
      create_namespace = false
      chart            = "${path.module}/helm-values/efs"
      chart_version    = "0.0.1"
      values = [
        <<-EOT
          pv:
            name: efs-persist-shared
            volumeHandle: ${module.efs[0].id}::${aws_efs_access_point.efs_shared_ap[count.index].id}
          pvc:
            name: efs-persist-shared
        EOT
      ]
    }
  }

  depends_on = [
    kubernetes_namespace.jupyterhub,
    module.efs
  ]
}

#---------------------------------------------------------------
# Additional Resources
#---------------------------------------------------------------
resource "kubernetes_secret_v1" "huggingface_token" {
  count = var.enable_jupyterhub ? 1 : 0
  metadata {
    name      = "hf-token"
    namespace = kubernetes_namespace.jupyterhub[count.index].metadata[0].name
  }

  data = {
    token = var.huggingface_token
  }
}

resource "kubernetes_config_map_v1" "notebook" {
  count = var.enable_jupyterhub ? 1 : 0
  metadata {
    name      = "notebook"
    namespace = kubernetes_namespace.jupyterhub[count.index].metadata[0].name
  }
}
