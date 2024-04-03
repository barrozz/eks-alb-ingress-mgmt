################################################################################
# Sub-Module Usage on Existing/Separate Cluster
################################################################################

# module "eks_managed_node_group" {
#   source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
#   version = "~> 17.10.0"
#   name            = "separate-eks-mng"
#   cluster_name    = module.eks.cluster_id
#   cluster_version = module.eks.cluster_version

#   vpc_id                            = module.vpc.vpc_id
#   subnet_ids                        = module.vpc.private_subnets
#   cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
#   vpc_security_group_ids = [
#     "${module.eks.cluster_security_group_id}",
#   ]

#   tags = merge(local.tags, { Separate = "eks-managed-node-group" })
# }

module "fargate_profile" {
  source = "terraform-aws-modules/eks/aws//modules/fargate-profile"

  # version = "~> 17.10.0"
  name         = "separate-fargate-profile"
  cluster_name = module.eks.cluster_id

  subnet_ids = module.vpc.private_subnets

  selectors = [{
    namespace = "kube-system"
    labels = {
      k8s-app = "kube-dns"
    }
  }]

  tags = merge(local.tags, { Separate = "fargate-profile" })
}

# module "self_managed_node_group" {
#   source = "terraform-aws-modules/eks/aws//modules/self-managed-node-group"
#   version = "~> 17.10.0"
#   name                = "separate-self-mng"
#   cluster_name        = module.eks.cluster_id
#   cluster_version     = module.eks.cluster_version
#   cluster_endpoint    = module.eks.cluster_endpoint
#   cluster_auth_base64 = module.eks.cluster_certificate_authority_data

#   instance_type = "m5.large"

#   vpc_id     = module.vpc.vpc_id
#   subnet_ids = module.vpc.private_subnets
#   vpc_security_group_ids = [
#     "${module.eks.cluster_primary_security_group_id}",
#     "${module.eks.cluster_security_group_id}",
#   ]

#   use_default_tags = true

#   tags = merge(local.tags, { Separate = "self-managed-node-group" })
# }

resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.tags
}

resource "aws_security_group" "additional" {
  name_prefix = "${local.name}-additional"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }

  # tags = local.tags
}

#################################
# EKS Module
#################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 18.20.1"

  cluster_name    = local.name
  cluster_version = local.cluster_version
  # "1.21"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  cluster_encryption_config = [{
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  # Self Managed Node Group(s)
  # self_managed_node_group_defaults = {
  #   vpc_security_group_ids = [
  # "${aws_security_group.additional.id}"
  #   ]
  #   iam_role_additional_policies = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
  # }

  # self_managed_node_groups = {
  #   spot = {
  # instance_type = "m5.large"
  # instance_market_options = {
  #   market_type = "spot"
  # }
  # 
  # pre_bootstrap_user_data = <<-EOT
  # echo "foo"
  # export FOO=bar
  # EOT
  # 
  # bootstrap_extra_args = "--kubelet-extra-args '--node-labels=node.kubernetes.io/lifecycle=spot'"
  # 
  # post_bootstrap_user_data = <<-EOT
  # cd /tmp
  # sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
  # sudo systemctl enable amazon-ssm-agent
  # sudo systemctl start amazon-ssm-agent
  # EOT
  #   }
  # 
  # }

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    disk_size      = 50
    instance_types = ["t3a.micro", "t3.micro"]
    # instance_types = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]

    attach_cluster_primary_security_group = true
    vpc_security_group_ids                = ["${aws_security_group.additional.id}"]
  }

  eks_managed_node_groups = {
    blue = {

    }
    green = {
      min_size     = 1
      max_size     = 4
      desired_size = 1

      instance_types = ["t3.micro"]
      capacity_type  = "SPOT"
      labels = {
        Environment = "test"
        GithubRepo  = "terraform-aws-eks"
        GithubOrg   = "terraform-aws-modules"
      }

      taints = {
        dedicated = {
          key    = "dedicated"
          value  = "gpuGroup"
          effect = "NO_SCHEDULE"
        }
      }

      update_config = {
        max_unavailable_percentage = 50 # or set `max_unavailable`
      }

      tags = {
        ExtraTag = "example"
      }
    }
  }

  # Fargate Profile(s)
  fargate_profiles = {
    default = {
      name       = "default"
      subnet_ids = module.vpc.private_subnets

      selectors = [
        {
          namespace = "kube-system"
          labels = {
            k8s-app = "kube-dns"
          }
        },
        {
          namespace = "default"
        }
      ]

      # tags = {
      #   Owner = var.owner
      # }

      timeouts = {
        create = "20m"
        delete = "20m"
      }
    }
  }

  # aws-auth configmap
  manage_aws_auth_configmap = false

  # use first time when configmap isn't exist
  # create_aws_auth_configmap = true

  #   aws_auth_node_iam_role_arns_non_windows = [
  #     module.eks_managed_node_group.iam_role_arn,
  #     module.self_managed_node_group.iam_role_arn,
  #   ]
  #   aws_auth_fargate_profile_pod_execution_role_arns = [
  #     module.fargate_profile.fargate_profile_pod_execution_role_arn
  #   ]

  # aws
    # aws_auth_roles = [
        # {
        # rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/barroz"
        # username = "barroz"
        # groups   = ["system:masters"]
        # },
    # ]

  # k8s
  aws_auth_users = [
    {
      # TODO: can be edited with data attributes
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/barroz"
      username = "barroz"
      groups   = ["system:masters"]
    },
  ]

  aws_auth_accounts = [
    "${data.aws_caller_identity.current.account_id}",
  ]

  tags = local.tags
}
