locals {
  cognito_custom_domain = var.cognito_custom_domain
  jupyterhub_values = templatefile("${path.module}/helm-values/jupyterhub-values-${var.jupyter_hub_auth_mechanism}.yaml", {
    ssl_cert_arn                = try(data.aws_acm_certificate.issued[0].arn, "")
    jupyterdomain               = try("https://${var.jupyterhub_domain}/hub/oauth_callback", "")
    authorize_url               = var.oauth_domain != "" ? "${var.oauth_domain}/auth" : try("https://${local.cognito_custom_domain}.auth.${local.region}.amazoncognito.com/oauth2/authorize", "")
    token_url                   = var.oauth_domain != "" ? "${var.oauth_domain}/token" : try("https://${local.cognito_custom_domain}.auth.${local.region}.amazoncognito.com/oauth2/token", "")
    userdata_url                = var.oauth_domain != "" ? "${var.oauth_domain}/userinfo" : try("https://${local.cognito_custom_domain}.auth.${local.region}.amazoncognito.com/oauth2/userInfo", "")
    username_key                = try(var.oauth_username_key, "")
    client_id                   = var.oauth_jupyter_client_id != "" ? var.oauth_jupyter_client_id : try(aws_cognito_user_pool_client.user_pool_client[0].id, "")
    client_secret               = var.oauth_jupyter_client_secret != "" ? var.oauth_jupyter_client_secret : try(aws_cognito_user_pool_client.user_pool_client[0].client_secret, "")
    user_pool_id                = try(aws_cognito_user_pool.pool[0].id, "")
    identity_pool_id            = try(aws_cognito_identity_pool.identity_pool[0].id, "")
    jupyter_single_user_sa_name = kubernetes_service_account_v1.jupyterhub_single_user_sa[0].metadata[0].name
    region                      = var.region
  })
}
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

resource "kubectl_manifest" "jupyterhub" {
  count = var.enable_jupyterhub ? 1 : 0
  yaml_body = templatefile("${path.module}/argocd-addons/jupyterhub.yaml", {
    user_values_yaml = indent(8, local.jupyterhub_values)
  })

  depends_on = [
    helm_release.argocd,
    kubernetes_config_map_v1.notebook,
    aws_secretsmanager_secret_version.postgres,
    module.efs_config,
    aws_efs_access_point.efs_persist_ap,
    aws_efs_access_point.efs_shared_ap
  ]
}
