
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  name            = "ex-${replace(basename(path.cwd), "_", "-")}"
  cluster_version = "1.29"
  region          = var.region

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    Example    = local.name
    GithubRepo = "terraform-aws-eks"
    GithubOrg  = "terraform-aws-modules"
  }
}


# module "disabled_self_managed_node_group" {
#   source = "../../modules/self-managed-node-group"

#   create = false

#   # Hard requirement
#   cluster_service_cidr = ""
# }

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 48)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 52)]

  enable_nat_gateway = false
  single_nat_gateway = true

  enable_vpn_gateway            = false
  create_database_subnet_group  = true
  create_database_subnet_route_table = true
  # TODO: rm for real prod
  create_database_internet_gateway_route = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}

data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${local.cluster_version}-v*"]
  }
}

# data "aws_ami" "eks_default_bottlerocket" {
#   most_recent = true
#   owners      = ["amazon"]

#   filter {
#     name   = "name"
#     values = ["bottlerocket-aws-k8s-${local.cluster_version}-x86_64-*"]
#   }
# }

# module "key_pair" {
#   source  = "terraform-aws-modules/key-pair/aws"
#   version = "~> 2.0"

#   key_name_prefix    = local.name
#   create_private_key = true

#   tags = local.tags
# }

# module "ebs_kms_key" {
#   source  = "terraform-aws-modules/kms/aws"
#   version = "~> 2.0"

#   description = "Customer managed key to encrypt EKS managed node group volumes"

#   # Policy
#   key_administrators = [
#     data.aws_caller_identity.current.arn
#   ]

#   key_service_roles_for_autoscaling = [
#     # required for the ASG to manage encrypted volumes for nodes
#     "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
#     # required for the cluster / persistentvolume-controller to create encrypted PVCs
#     module.eks.cluster_iam_role_arn,
#   ]

#   # Aliases
#   aliases = ["eks/${local.name}/ebs"]

#   tags = local.tags
# }

# module "kms" {
#   source  = "terraform-aws-modules/kms/aws"
#   version = "~> 2.1"

#   aliases               = ["eks/${local.name}"]
#   description           = "${local.name} cluster encryption key"
#   enable_default_policy = true
#   key_owners            = [data.aws_caller_identity.current.arn]

#   tags = local.tags
# }

# resource "aws_iam_policy" "additional" {
#   name        = "${local.name}-additional"
#   description = "Example usage of node additional policy"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [
#           "ec2:Describe*",
#         ]
#         Effect   = "Allow"
#         Resource = "*"
#       },
#     ]
#   })

#   tags = local.tags
# }