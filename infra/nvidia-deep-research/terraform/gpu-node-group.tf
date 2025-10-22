#---------------------------------------------------------------
# GPU Node Groups Configuration
#---------------------------------------------------------------

#---------------------------------------------------------------
# Common Configuration
#---------------------------------------------------------------
variable "gpu_node_volume_size" {
  description = "EBS volume size in GB for GPU nodes"
  type        = number
  default     = 500
}

variable "gpu_node_volume_type" {
  description = "EBS volume type for GPU nodes"
  type        = string
  default     = "gp3"
}

#---------------------------------------------------------------
# GPU Node Group 1 (Main workload group)
#---------------------------------------------------------------
variable "gpu_nodegroup_1_enabled" {
  description = "Enable GPU node group 1"
  type        = bool
  default     = false
}

variable "gpu_nodegroup_1_name" {
  description = "Name for GPU node group 1"
  type        = string
  default     = "gpu-nodegroup-1"
}

variable "gpu_nodegroup_1_instance_types" {
  description = "Instance types for GPU node group 1"
  type        = list(string)
  default     = ["g5.48xlarge"]
}

variable "gpu_nodegroup_1_min_size" {
  type    = number
  default = 0
}

variable "gpu_nodegroup_1_max_size" {
  type    = number
  default = 5
}

variable "gpu_nodegroup_1_desired_size" {
  type    = number
  default = 1
}

#---------------------------------------------------------------
# GPU Node Group 2
#---------------------------------------------------------------
variable "gpu_nodegroup_2_enabled" {
  description = "Enable GPU node group 2"
  type        = bool
  default     = false
}

variable "gpu_nodegroup_2_name" {
  description = "Name for GPU node group 2"
  type        = string
  default     = "gpu-nodegroup-2"
}

variable "gpu_nodegroup_2_instance_types" {
  description = "Instance types for GPU node group 2"
  type        = list(string)
  default     = ["g5.xlarge"]
}

variable "gpu_nodegroup_2_min_size" {
  type    = number
  default = 0
}

variable "gpu_nodegroup_2_max_size" {
  type    = number
  default = 5
}

variable "gpu_nodegroup_2_desired_size" {
  type    = number
  default = 1
}

#---------------------------------------------------------------
# Additional GPU Node Group 3
#---------------------------------------------------------------
variable "gpu_nodegroup_3_enabled" {
  description = "Enable GPU node group 3"
  type        = bool
  default     = false
}

variable "gpu_nodegroup_3_name" {
  description = "Name for GPU node group 3"
  type        = string
  default     = "gpu-nodegroup-3"
}

variable "gpu_nodegroup_3_instance_types" {
  description = "Instance types for GPU node group 3"
  type        = list(string)
  default     = ["p3.8xlarge"]
}

variable "gpu_nodegroup_3_min_size" {
  type    = number
  default = 0
}

variable "gpu_nodegroup_3_max_size" {
  type    = number
  default = 2
}

variable "gpu_nodegroup_3_desired_size" {
  type    = number
  default = 0
}

#---------------------------------------------------------------
# Create additional GPU node groups
#---------------------------------------------------------------
# Note: We use standalone aws_eks_node_group resources but configure them
# to use the same security group as EKS module node groups for DNS access

# GPU Node Group 1
resource "aws_eks_node_group" "gpu_nodegroup_1" {
  count = var.gpu_nodegroup_1_enabled ? 1 : 0

  cluster_name    = module.eks.cluster_name
  node_group_name = var.gpu_nodegroup_1_name
  node_role_arn   = module.eks.eks_managed_node_groups["core_node_group"].iam_role_arn
  subnet_ids      = local.secondary_cidr_subnets

  ami_type       = "AL2023_x86_64_NVIDIA"
  instance_types = var.gpu_nodegroup_1_instance_types

  scaling_config {
    desired_size = var.gpu_nodegroup_1_desired_size
    max_size     = var.gpu_nodegroup_1_max_size
    min_size     = var.gpu_nodegroup_1_min_size
  }

  # Use launch template to specify node security group with DNS rules
  launch_template {
    id      = aws_launch_template.gpu_nodes[0].id
    version = "$Latest"
  }

  labels = {
    NodeGroupType            = var.gpu_nodegroup_1_name
    "nvidia.com/gpu.present" = "true"
    "accelerator"            = "nvidia"
  }

  taint {
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  tags = merge(local.tags, {
    Name = var.gpu_nodegroup_1_name
  })

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
}

# GPU Node Group 2
resource "aws_eks_node_group" "gpu_nodegroup_2" {
  count = var.gpu_nodegroup_2_enabled ? 1 : 0

  cluster_name    = module.eks.cluster_name
  node_group_name = var.gpu_nodegroup_2_name
  node_role_arn   = module.eks.eks_managed_node_groups["core_node_group"].iam_role_arn
  subnet_ids      = local.secondary_cidr_subnets

  ami_type       = "AL2023_x86_64_NVIDIA"
  instance_types = var.gpu_nodegroup_2_instance_types

  scaling_config {
    desired_size = var.gpu_nodegroup_2_desired_size
    max_size     = var.gpu_nodegroup_2_max_size
    min_size     = var.gpu_nodegroup_2_min_size
  }

  # Use launch template to specify node security group with DNS rules
  launch_template {
    id      = aws_launch_template.gpu_nodes[0].id
    version = "$Latest"
  }

  labels = {
    NodeGroupType            = var.gpu_nodegroup_2_name
    "nvidia.com/gpu.present" = "true"
    "accelerator"            = "nvidia"
  }

  taint {
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  tags = merge(local.tags, {
    Name = var.gpu_nodegroup_2_name
  })

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
}

# GPU Node Group 3
resource "aws_eks_node_group" "gpu_nodegroup_3" {
  count = var.gpu_nodegroup_3_enabled ? 1 : 0

  cluster_name    = module.eks.cluster_name
  node_group_name = var.gpu_nodegroup_3_name
  node_role_arn   = module.eks.eks_managed_node_groups["core_node_group"].iam_role_arn
  subnet_ids      = local.secondary_cidr_subnets

  ami_type       = "AL2023_x86_64_NVIDIA"
  instance_types = var.gpu_nodegroup_3_instance_types

  scaling_config {
    desired_size = var.gpu_nodegroup_3_desired_size
    max_size     = var.gpu_nodegroup_3_max_size
    min_size     = var.gpu_nodegroup_3_min_size
  }

  # Use launch template to specify node security group with DNS rules
  launch_template {
    id      = aws_launch_template.gpu_nodes[0].id
    version = "$Latest"
  }

  labels = {
    NodeGroupType            = var.gpu_nodegroup_3_name
    "nvidia.com/gpu.present" = "true"
    "accelerator"            = "nvidia"
  }

  taint {
    key    = "nvidia.com/gpu"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  tags = merge(local.tags, {
    Name = var.gpu_nodegroup_3_name
  })

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
}

#---------------------------------------------------------------
# Launch Template with Node Security Group for DNS Access
#---------------------------------------------------------------
resource "aws_launch_template" "gpu_nodes" {
  count = var.gpu_nodegroup_1_enabled || var.gpu_nodegroup_2_enabled || var.gpu_nodegroup_3_enabled ? 1 : 0

  name_prefix = "${local.name}-gpu-nodes-"
  description = "Launch template for GPU nodes with proper security group configuration"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.gpu_node_volume_size
      volume_type           = var.gpu_node_volume_type
      delete_on_termination = true
      encrypted             = true
    }
  }

  # Attach both cluster and node security groups
  # Node security group has DNS port 53 rules required for CoreDNS access
  vpc_security_group_ids = [
    module.eks.cluster_security_group_id,
    module.eks.node_security_group_id
  ]

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.tags, {
      Name = "${local.name}-gpu-node"
    })
  }

  tags = merge(local.tags, {
    Name = "${local.name}-gpu-launch-template"
  })
}

