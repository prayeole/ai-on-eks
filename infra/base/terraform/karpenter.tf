locals {
  ec2nodeclass = templatefile("${path.module}/karpenter-resources/templates/${var.ami_family}_ec2nodeclass.tpl",
    {
      node_iam_role                       = module.karpenter.node_iam_role_name
      cluster_name                        = module.eks.cluster_name
      enable_soci_snapshotter             = var.enable_soci_snapshotter
      soci_snapshotter_use_instance_store = var.soci_snapshotter_use_instance_store
      data_disk_snapshot_id               = var.bottlerocket_data_disk_snapshot_id
      max_user_namespaces                 = var.max_user_namespaces
    }
  )
  ec2nodeclass_manifests = {
    for f in fileset("${path.module}/karpenter-resources/nodeclass", "*.yaml") :
    f => templatefile("${path.module}/karpenter-resources/nodeclass/${f}", {
      ec2nodeclass = local.ec2nodeclass
    })
  }
  karpenter_node_pools = {
    for f in fileset("${path.module}/karpenter-resources/nodepool", "*.yaml") :
    f => templatefile("${path.module}/karpenter-resources/nodepool/${f}", {
    })
  }
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 21.4"

  cluster_name = module.eks.cluster_name
  namespace    = "karpenter"

  # Name needs to match role name passed to the EC2NodeClass
  node_iam_role_use_name_prefix   = false
  node_iam_role_name              = "karpenter-${local.name}"
  create_pod_identity_association = true

  # Used to attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}


resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "karpenter"
  create_namespace = true
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "1.6.3"
  wait             = true

  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password

  values = [
    <<-EOT
    nodeSelector:
      NodeGroupType: 'core'
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      - key: karpenter.sh/controller
        operator: Exists
        effect: NoSchedule
    webhook:
      enabled: false
    EOT
  ]

  depends_on = [module.karpenter]
}

resource "kubectl_manifest" "ec2nodeclass" {
  for_each = { for idx, manifest in local.ec2nodeclass_manifests : idx => manifest }

  yaml_body = each.value
  wait      = true
  depends_on = [
    helm_release.karpenter
  ]
}

resource "kubectl_manifest" "nodepool" {
  for_each = local.karpenter_node_pools

  yaml_body = each.value

  depends_on = [
    helm_release.karpenter
  ]
}
