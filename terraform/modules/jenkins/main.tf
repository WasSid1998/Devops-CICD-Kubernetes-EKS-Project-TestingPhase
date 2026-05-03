variable "project"          {}
variable "env"              {}
variable "vpc_id"           {}
variable "public_subnet_id" {}   
variable "your_ip"          {}   
variable "vpc_cidr"         {}

resource "aws_security_group" "jenkins" {
  name        = "${var.project}-${var.env}-jenkins-sg"
  description = "Jenkins - only allow your IP"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${var.your_ip}/32"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.your_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-${var.env}-jenkins-sg" }
}


resource "aws_iam_role" "jenkins" {
  name = "${var.project}-${var.env}-jenkins-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "jenkins" {
  name = "${var.project}-${var.env}-jenkins-policy"
  role = aws_iam_role.jenkins.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::myapp-tf-state",
          "arn:aws:s3:::myapp-tf-state/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project}-${var.env}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}

resource "aws_key_pair" "jenkins" {
  key_name   = "${var.project}-${var.env}-jenkins-key"
  public_key = file("~/.ssh/myapp-jenkins.pub")
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "jenkins" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.medium"
  subnet_id                   = var.public_subnet_id   # ← public subnet
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins.name
  key_name                    = aws_key_pair.jenkins.key_name
  associate_public_ip_address = true    # ← gets a public IP

  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    echo "=== Installing Java ==="
    yum install -y java-17-amazon-corretto-devel

    echo "=== Installing Jenkins ==="
    wget -O /etc/yum.repos.d/jenkins.repo \
      https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import \
      https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    yum install -y jenkins
    systemctl start jenkins
    systemctl enable jenkins

    echo "=== Installing Docker ==="
    amazon-linux-extras install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker jenkins

    echo "=== Installing kubectl ==="
    curl -LO "https://dl.k8s.io/release/$(curl -sL \
      https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl && mv kubectl /usr/local/bin/

    echo "=== Installing AWS CLI ==="
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
      -o "awscliv2.zip"
    unzip awscliv2.zip && ./aws/install

    echo "=== Installing Git ==="
    yum install -y git

    echo "=== Connecting kubectl to all EKS clusters ==="
    aws eks update-kubeconfig \
      --region us-east-1 --name ${var.project}-dev
    aws eks update-kubeconfig \
      --region us-east-1 --name ${var.project}-preprod
    aws eks update-kubeconfig \
      --region us-east-1 --name ${var.project}-prod

    echo "=== Done ==="
  EOF

  tags = { Name = "${var.project}-${var.env}-jenkins" }
}

output "jenkins_public_ip"  { value = aws_instance.jenkins.public_ip }
output "jenkins_public_dns" { value = aws_instance.jenkins.public_dns }
output "jenkins_url"        { value = "http://${aws_instance.jenkins.public_ip}:8080" }