variable "project" {}
variable "env" {}

resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true
    tags = {
        Name = "${var.project}-${var.env}-vpc"
    }
}

resource "aws_internet_gateway" "internet" {
    vpc_id = aws_vpc.vpc.id
    tags = {
      Name = "${var.project}-${var.env}-igw"
    }
}

resource "aws_subnet" "Public" {
    count = 2
    vpc_id = aws_vpc.vpc.id
    cidr_block = ["10.0.101.0/24","10.0.102.0/24"][count.index]
    availability_zone = ["us-east-1a","us-east-1b"][count.index]
    map_public_ip_on_launch = true
    tags = {
      Name = "${var.project}-${var.env}-public-${count.index}"
      "kubernetes.io/role/elb" = "1"
      "kubernetes.io/cluster/${var.project}-${var.env}" = "owned"
    }
}

resource "aws_subnet" "Private" {
    count = 2
    vpc_id = aws_vpc.vpc.id
    cidr_block = ["10.0.1.0/24","10.0.2.0/24"][count.index]
    availability_zone = ["us-east-1a","us-east-1b"][count.index]
    tags = {
      Name = "${var.project}-${var.env}-private-${count.index}"
      "kubernetes.io/role/internal-elb" = "1"
      "kubernetes.io/cluster/${var.project}-${var.env}" = "owned"
    }
}

resource "aws_eip" "nat" {
    count = 2
    domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
    count = 2
    allocation_id = aws_eip.nat[count.index].id
    subnet_id = aws_subnet.Public[count.index].id
    depends_on = [ aws_internet_gateway.internet ]
  
}

resource "aws_route_table" "Public" {
    vpc_id = aws_vpc.vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.internet.id
    }
}

resource "aws_route_table_association" "Public" {
    count = 2
    subnet_id = aws_subnet.Public[count.index].id
    route_table_id = aws_route_table.Public.id
}

resource "aws_route_table" "Private" {
    count = 2
    vpc_id = aws_vpc.vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat[count.index].id
    }
}

resource "aws_route_table_association" "Private" {
    count = 2
    subnet_id = aws_subnet.Private[count.index].id
    route_table_id = aws_route_table.Private.id[count.index].id
}

resource "aws_security_group" "eks" {
    name = "${var.project}-${var.env}-ekssec"
    vpc_id = aws_vpc.vpc.id

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        security_groups = [aws_security_group.alb.id]
    }

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        self = true
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "rds" {
    name = "${var.project}-${var.env}-rdssec"
    vpc_id = aws_vpc.vpc.id

    ingress {
        from_port = 5432
        to_port = 5432
        protocol = "tcp"
        security_groups = [aws_security_group.eks.id]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "alb" {
    name = "${var.project}-${var.env}-albsec"
    vpc_id = aws_vpc.vpc.id

    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

output "vpc_id" {
    value = aws_vpc.vpc.id
}

output "public_subnet_ids" {
    value = aws_subnet.Public[*].id
}

output "private_subnet_ids" {
    value = aws_subnet.Private[*].id
}

output "eks_sg_id" {
    value = aws_security_group.eks.id
}

output "alb_sg_id" {
    value = aws_security_group.alb.id
}

output "rds_sg_id" {
    value = aws_security_group.rds.id
}