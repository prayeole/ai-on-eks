name          = "nvidia-deep-research"
enable_argocd = true
# region              = "us-west-2"
# eks_cluster_version = "1.33"

# -------------------------------------------------------------------------------------
# EKS Addons Configuration
#
# These are the EKS Cluster Addons managed by Terrafrom stack.
# You can enable or disable any addon by setting the value to `true` or `false`.
#
# If you need to add a new addon that isn't listed here:
# 1. Add the addon name to the `enable_cluster_addons` variable in `base/terraform/variables.tf`
# 2. Update the `locals.cluster_addons` logic in `eks.tf` to include any required configuration
#
# -------------------------------------------------------------------------------------

# Common GPU node configuration
gpu_node_volume_size = 500   # EBS volume size in GB
gpu_node_volume_type = "gp3" # EBS volume type (gp3, gp2, io1, io2)

# GPU Node Group 1 (Main workload - g5.48xlarge)
gpu_nodegroup_1_enabled        = false
gpu_nodegroup_1_name           = "main-ng"
gpu_nodegroup_1_instance_types = ["g5.48xlarge"]
gpu_nodegroup_1_min_size       = 1
gpu_nodegroup_1_max_size       = 1
gpu_nodegroup_1_desired_size   = 1

# GPU Node Group 2
gpu_nodegroup_2_enabled        = false
gpu_nodegroup_2_name           = "secondary-ng"
gpu_nodegroup_2_instance_types = ["g5.12xlarge"]
gpu_nodegroup_2_min_size       = 1
gpu_nodegroup_2_max_size       = 1
gpu_nodegroup_2_desired_size   = 1

# GPU Node Group 3
gpu_nodegroup_3_enabled        = false
gpu_nodegroup_3_name           = "data-ingest-ng"
gpu_nodegroup_3_instance_types = ["g5.12xlarge"]
gpu_nodegroup_3_min_size       = 1
gpu_nodegroup_3_max_size       = 1
gpu_nodegroup_3_desired_size   = 1

# -------------------------------------------------------------------------------------
# Karpenter Custom NodePools Configuration
#
# Enable/disable P4 (A100) and P5 (H100) GPU instance support
# P4 families: p4d, p4de (8x A100 - 40GB or 80GB VRAM)
# P5 families: p5, p5e, p5en (1-8x H100)
# -------------------------------------------------------------------------------------
enable_p4_karpenter = true # p4d/p4de.24xlarge (8x A100)
enable_p5_karpenter = true # p5*.{4,48}xlarge (1-8x H100)

# -------------------------------------------------------------------------------------
# OpenSearch Serverless Configuration
# 
# Set enable_opensearch_serverless = true to create everything:
# 1. OpenSearch Serverless collection (vector search)
# 2. Encryption, network, and data access policies
# 3. IAM role and policy (IRSA)
# 4. Kubernetes namespace and service account
#
# Based on the manual setup guide in the README
# -------------------------------------------------------------------------------------
enable_opensearch_serverless    = true
opensearch_collection_name      = "osv-vector-dev"
opensearch_collection_type      = "VECTORSEARCH"
opensearch_policy_name          = "osv-vector-dev-policy"
opensearch_allow_public_access  = true
opensearch_namespace            = "nv-nvidia-blueprint-rag" # Namespace where your pods will run
opensearch_service_account_name = "opensearch-access-sa"
opensearch_iam_role_name        = "EKSOpenSearchServerlessRole"
