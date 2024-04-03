terraform {
  required_version = ">= 1.3.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.10.0"
    }

    # kubectl = {
    #   source  = "gavinbunney/kubectl"
    #   version = ">= 1.14"
    # }
  }
}

locals {
  config_path = "${path.module}/kubeconfig_${var.project}-${terraform.workspace}-eks"
}

provider "aws" {

  # add version pinning
  profile = var.profile
  region  = var.region

  default_tags {
    tags = {
      project = var.project
      owner   = var.owner
    }
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    config_path            = local.config_path
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  }
}

# TODO: is kubectl needed ???
# provider "kubectl" {
#   host                   = module.eks.cluster_endpoint
#   cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

# #   exec {
# #     api_version = "client.authentication.k8s.io/v1beta1"
# #     command     = "aws"
# #     args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
# #   }
# }

# resource "null_resource" "update_kubeconfig" {
#   # Ensures this runs after the EKS cluster has been created
#   depends_on = [module.eks]

#   provisioner "local-exec" {
#     command = "aws eks --region us-east-1 update-kubeconfig --name ${module.eks.cluster_name}"
#   }
# }