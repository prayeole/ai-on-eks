resource "aws_eks_addon" "aws_ebs_csi_driver" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "PRESERVE"
  service_account_role_arn    = module.ebs_csi_driver_irsa.iam_role_arn
  depends_on                  = [module.ebs_csi_driver_irsa]
}
