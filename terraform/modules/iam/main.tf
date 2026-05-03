variable "project" {}
variable "env" {}
variable "oidc_url" {}
variable "oidc_arn" {}
variable "secret_arn" {}

###For EKS CLUSTER ROLE

resource "aws_iam_role" "eks_cluster" {
    name = "${var.project}-${var.env}-ekscluster-role"
    assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": [
                    "eks.amazonaws.com"
                ]
            },
            "Action": "sts:AssumeRole"
        }
    ]
    }) 
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
    role = aws_iam_role.eks_cluster.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  
}


### FOR EKS NODE ROLE

resource "aws_iam_role" "eks_node" {
    name = "${var.project}-${var.env}-eks-node-role"
    assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole"
            ],
            "Principal": {
                "Service": [
                    "ec2.amazonaws.com"
                ]
            }
        }
    ]
  })
  
}

resource "aws_iam_role_policy_attachment" "worker" {
    role = aws_iam_role.eks_node.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni" {
    role = aws_iam_role.eks_node.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
    role = aws_iam_role.eks_node.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"    
}

#### For Pod IAM Role
resource "aws_iam_role" "app_pod" {
  name = "${var.project}-${var.env}-app-pod-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRoleWithWebIdentity",
        Principal = {
          Federated = var.oidc_arn
        },
        Condition = {
          StringEquals = {
            "${replace(var.oidc_url, "https://", "")}:sub" = "system:serviceaccount:default:app-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "app_pod_secrets" {
    role = aws_iam_role.app_pod.name
    policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": [var.secret_arn]
            }
    ]
  })
}

output "cluster_role_arn" {
    value = aws_iam_role.eks_cluster.arn
}

output "node_role_arn" {
    value = aws_iam_role.eks_node.arn
}

output "app_pod_role_arn" {
    value = aws_iam_role.app_pod.arn
}



