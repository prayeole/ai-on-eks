# GPU Node Groups Configuration

Add 3 custom GPU node groups **WITHOUT modifying** `_LOCAL/eks.tf`.

## What You Get

You'll have **4 GPU node groups total**:

1. **nvidia-gpu** - Base node group with `g6.4xlarge` (desired_size=0, no cost)
2. **gpu-nodegroup-1** - Your main workload node group
3. **gpu-nodegroup-2** - Your secondary node group
4. **gpu-nodegroup-3** - Your data ingest node group

## Quick Start

Edit `blueprint.tfvars`:

```hcl
# Common GPU node configuration
gpu_node_volume_size = 500   # EBS volume size in GB
gpu_node_volume_type = "gp3" # Volume type

# GPU Node Group 1 (Main workload)
gpu_nodegroup_1_enabled        = true
gpu_nodegroup_1_name           = "main-workload-ng"
gpu_nodegroup_1_instance_types = ["g5.48xlarge"]
gpu_nodegroup_1_min_size       = 1
gpu_nodegroup_1_max_size       = 3
gpu_nodegroup_1_desired_size   = 1

# GPU Node Group 2
gpu_nodegroup_2_enabled        = true
gpu_nodegroup_2_name           = "secondary_ng"
gpu_nodegroup_2_instance_types = ["g5.12xlarge"]
gpu_nodegroup_2_min_size       = 1
gpu_nodegroup_2_max_size       = 1
gpu_nodegroup_2_desired_size   = 1

# GPU Node Group 3
gpu_nodegroup_3_enabled        = true
gpu_nodegroup_3_name           = "data_ingest_ng"
gpu_nodegroup_3_instance_types = ["g5.12xlarge"]
gpu_nodegroup_3_min_size       = 1
gpu_nodegroup_3_max_size       = 1
gpu_nodegroup_3_desired_size   = 1
```

## What You Get

✅ **3 custom GPU node groups** (plus 1 base with 0 nodes)  
✅ **NO modifications** to `_LOCAL/eks.tf`  
✅ **Automatic GPU taints** and labels  
✅ **Independent scaling** for each group  
✅ **Different instance types** per group  

## Common Instance Types

- `g5.xlarge` - 1x A10G (24GB), 4 vCPU
- `g5.12xlarge` - 4x A10G (96GB), 48 vCPU
- `g5.48xlarge` - 8x A10G (192GB), 192 vCPU
- `g6.xlarge`, `g6.2xlarge` - Latest generation (NVIDIA L4)
- `p3.8xlarge`, `p3.16xlarge` - Training workloads (NVIDIA V100)
- `p4d.24xlarge` - High-performance training (8x A100)

## Note About Base Node Group

The base `nvidia-gpu` node group exists with `g6.4xlarge` but has `desired_size = 0`, so no nodes will be created (no cost). Your 3 custom node groups (1, 2, 3) will be the active ones.

## Apply Changes

```bash
cd _LOCAL
terraform init
terraform plan -var-file=../blueprint.tfvars
terraform apply -var-file=../blueprint.tfvars
```

