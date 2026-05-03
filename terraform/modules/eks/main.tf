variable "project" {}
variable "env" {}
variable "private_subnets" {}
variable "eks_sg_id" {}
variable "cluster_role_arn" {}
variable "node_role_arn" {}
variable "node_size" {
    default = "t3-medium"
}  
variable "min_nodes" {
    default = 2
}
variable "max_nodes" {
    default = 5
}

resource "aws_eks_cluster" "eks" {
    name = "${var.project}-${var.env}"
    role_arn = var.cluster_role_arn

    vpc_config {
      subnet_ids = var.private_subnets
      endpoint_private_access = true
      endpoint_public_access = false
      security_group_ids = [var.eks_sg_id]
    }

    enabled_cluster_log_types = ["api","audit"]
}

resource "aws_eks_node_group" "nodegrp" {
    cluster_name = aws_eks_cluster.eks.name
    node_group_name = "${var.project}-${var.env}-nodes"
    node_role_arn = var.node_role_arn
    subnet_ids = var.private_subnets
    instance_types = [var.node_size]
    depends_on = [ aws_eks_cluster.eks ]

    scaling_config {
      desired_size = var.min_nodes
      min_size = var.min_nodes
      max_size = var.max_nodes
    }

    update_config {
      max_unavailable = 1
    }
}

resource "aws_ecr_repository" "app" {
    name = "${var.project}-${var.env}"
    image_tag_mutability = "MUTABLE"
    image_scanning_configuration {
      scan_on_push = true
    }
}

output "cluster_name" {
    value = aws_eks_cluster.eks.name
}

output "ecr_repo_url" {
    value = aws_ecr_repository.app.repository_url
}