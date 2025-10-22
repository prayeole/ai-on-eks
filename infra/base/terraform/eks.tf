#---------------------------------------
# Amazon EKS Managed Add-ons
#---------------------------------------

locals {
  # Filter secondary CIDR subnets (starting with "100.")
  secondary_cidr_subnets = compact([for subnet_id, cidr_block in zipmap(module.vpc.private_subnets, module.vpc.private_subnets_cidr_blocks) :
  substr(cidr_block, 0, 4) == "100." ? subnet_id : null])

  base_addons = {
    for name, enabled in var.enable_cluster_addons :
    name => {} if enabled
  }

  # Extended configurations used for specific addons with custom settings
  addon_overrides = {
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }

    eks-pod-identity-agent = {
      before_compute = true
    }

    amazon-cloudwatch-observability = {
      preserve                 = true
      service_account_role_arn = aws_iam_role.cloudwatch_observability_role.arn
    }
  }

  # Merge base with overrides
  cluster_addons = {
    for name, config in local.base_addons :
    name => merge(config, lookup(local.addon_overrides, name, {}))
  }
}

#---------------------------------------------------------------
# EKS Cluster
#---------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.4"

  name               = local.name
  kubernetes_version = var.eks_cluster_version

  #WARNING: Avoid using this option (cluster_endpoint_public_access = true) in preprod or prod accounts. This feature is designed for sandbox accounts, simplifying cluster deployment and testing.
  endpoint_public_access = true

  # Add the IAM identity that terraform is using as a cluster admin
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  # EKS Add-ons
  addons = local.cluster_addons

  vpc_id = module.vpc.vpc_id

  # Filtering only Secondary CIDR private subnets starting with "100.".
  # Subnet IDs where the EKS Control Plane ENIs will be created
  subnet_ids = local.secondary_cidr_subnets

  # Combine root account, current user/role and additional roles to be able to access the cluster KMS key - required for terraform updates
  kms_key_administrators = distinct(concat([
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"],
    var.kms_key_admin_roles,
    [data.aws_iam_session_context.current.issuer_arn]
  ))

  create_security_group      = false
  create_node_security_group = false

  eks_managed_node_groups = merge({
    #  It's recommended to have a Managed Node group for hosting critical add-ons
    #  It's recommended to use Karpenter to place your workloads instead of using Managed Node groups
    #  You can leverage nodeSelector and Taints/tolerations to distribute workloads across Managed Node group or Karpenter nodes.
    core_node_group = {
      name        = "core-node-group"
      description = "EKS Core node group for hosting system add-ons"
      # Filtering only Secondary CIDR private subnets starting with "100.".
      # Subnet IDs where the nodes/node groups will be provisioned
      subnet_ids = local.secondary_cidr_subnets
      iam_role_additional_policies = {
        # Not required, but used in the example to access the nodes to inspect mounted volumes
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      node_repair_config = {
        enabled = true
      }
      ebs_optimized = true
      # This block device is used only for root volume. Adjust volume according to your size.
      # NOTE: Don't use this volume for ML workloads
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 100
            volume_type = "gp3"
          }
        }
      }
      # aws ssm get-parameters --names /aws/service/eks/optimized-ami/1.27/amazon-linux-2/recommended/image_id --region us-west-2
      ami_type     = "BOTTLEROCKET_x86_64" # Use this for Graviton AL2023_ARM_64_STANDARD
      min_size     = 2
      max_size     = 8
      desired_size = 2

      instance_types = ["m6i.xlarge"]

      labels = {
        WorkerType    = "ON_DEMAND"
        NodeGroupType = "core"
      }

      tags = merge(local.tags, {
        Name = "core-node-grp"
      })
    }

    # Node group for NVIDIA GPU workloads with NVIDIA K8s DRA Testing
    nvidia-gpu = {
      ami_type       = "AL2023_x86_64_NVIDIA"
      instance_types = ["g6.4xlarge"] # Use p4d for testing MIG
      subnet_ids     = local.secondary_cidr_subnets
      iam_role_additional_policies = {
        # Not required, but used in the example to access the nodes to inspect mounted volumes
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
      # Add security group rules on the node group security group to
      # allow EFA traffic
      enable_efa_support = true
      node_repair_config = {
        enabled = true
      }
      ebs_optimized = true
      # This block device is used only for root volume. Adjust volume according to your size.
      # NOTE: Don't use this volume for ML workloads
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 100
            volume_type = "gp3"
          }
        }
      }
      # Mount instance store volumes in RAID-0 for kubelet and containerd
      cloudinit_pre_nodeadm = [
        {
          content_type = "application/node.eks.aws"
          content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              instance:
                localStorage:
                  strategy: RAID0
          EOT
        }
      ]

      labels = {
        NodeGroupType            = "g6-mng"
        "nvidia.com/gpu.present" = "true"
        "accelerator"            = "nvidia"
      }

      min_size     = 0
      max_size     = 1
      desired_size = 0

      taints = {
        # Ensure only GPU workloads are scheduled on this node group
        gpu = {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }


    }, length(var.capacity_block_reservation_id) > 0 ? {
    cbr = {
      ami_type       = "AL2023_x86_64_NVIDIA"
      instance_types = ["p4de.24xlarge"]
      iam_role_additional_policies = {
        # Not required, but used in the example to access the nodes to inspect mounted volumes
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
      # Add security group rules on the node group security group to
      # allow EFA traffic
      enable_efa_support = true
      node_repair_config = {
        enabled = true
      }
      ebs_optimized = true
      # This block device is used only for root volume. Adjust volume according to your size.
      # NOTE: Don't use this volume for ML workloads
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 100
            volume_type = "gp3"
          }
        }
      }
      cloudinit_pre_nodeadm = [
        {
          content_type = "application/node.eks.aws"
          content      = <<-EOT
            ---
            apiVersion: node.eks.aws/v1alpha1
            kind: NodeConfig
            spec:
              instance:
                localStorage:
                  strategy: RAID0
          EOT
        }
      ]

      min_size     = 0
      max_size     = 1
      desired_size = 0

      # This will:
      # 1. Create a placement group to place the instances close to one another
      # 2. Ignore subnets that reside in AZs that do not support the instance type
      # 3. Expose all of the available EFA interfaces on the launch template
      enable_efa_support = true

      # NOTE: "nvidia.com/mig.config" label is required for MIG support to match with the MIG profile.
      # Check mig profiel config in infra/base/terraform/argocd-addons/nvidia-gpu-operator.yaml
      labels = {
        "nvidia.com/gpu.present"        = "true"
        "accelerator"                   = "nvidia"
        "nvidia.com/gpu.product"        = "A100-SXM4-80GB"
        "nvidia.com/mig.config"         = "p4de-half-balanced" # References GPU Operator embedded MIG profile
        "node-type"                     = "p4de"
        "vpc.amazonaws.com/efa.present" = "true"
      }

      taints = {
        # Ensure only GPU workloads are scheduled on this node group
        gpu = {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      #-------------------------------------
      # NOTE: CBR (Capacity Block Reservation) requires specific AZ placement
      # This uses the first available secondary CIDR subnet
      # TODO - Update the subnet to match the availability zone of YOUR capacity reservation
      #-------------------------------------
      subnet_ids = [local.secondary_cidr_subnets[0]]

      capacity_type = "CAPACITY_BLOCK"
      instance_market_options = {
        market_type = "capacity-block"
      }
      capacity_reservation_specification = {
        capacity_reservation_target = {
          capacity_reservation_id = var.capacity_block_reservation_id # Replace with your capacity reservation ID
        }
      }
    }
  } : {})
  tags = local.tags
}

# Add the Karpenter discovery tag only to the cluster primary security group
# by default if using the eks module tags, it will tag all resources with this tag, which is not needed.
resource "aws_ec2_tag" "cluster_primary_security_group" {
  resource_id = module.eks.cluster_primary_security_group_id
  key         = "karpenter.sh/discovery"
  value       = local.name
}

#---------------------------------------------------------------
# EKS Amazon CloudWatch Observability Role
#---------------------------------------------------------------
resource "aws_iam_role" "cloudwatch_observability_role" {
  name_prefix = "${local.name}-eks-cw-agent-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" : "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent",
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cloudwatch_observability_role.name
}

#---------------------------------------------------------------
# GP3 Encrypted Storage Class
#---------------------------------------------------------------
resource "kubernetes_annotations" "disable_gp2" {
  annotations = {
    "storageclass.kubernetes.io/is-default-class" : "false"
  }
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata {
    name = "gp2"
  }
  force = true

  depends_on = [module.eks.eks_cluster_id]
}

resource "kubernetes_storage_class" "default_gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" : "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"
  parameters = {
    fsType    = "ext4"
    encrypted = true
    type      = "gp3"
  }

  depends_on = [kubernetes_annotations.disable_gp2]
}
