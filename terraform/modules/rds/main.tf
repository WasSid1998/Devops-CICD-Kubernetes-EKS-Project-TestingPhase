variable "project" {}
variable "env" {}
variable "private_subnets" {}
variable "rds_sg_id" {}
variable "multi_az" {
    default = false
}
variable "backup_days" {
    default = 1
}
variable "deletion_protection" {
    default = false
}

resource "random_password" "db" {
    length = 25
    special = false
}

resource "aws_secretsmanager_secret" "db" {
    name = "${var.project}/${var.env}/db/credentials"
}

resource "aws_secretsmanager_secret_version" "db" {
    secret_id = aws_secretsmanager_secret.db.id
    secret_string = jsonencode({
        username = "appuser"
        password = random_password.db.result
        dbname = "appdb"
        host = aws_db_instance.ins.address
        })
}

resource "aws_db_subnet_group" "db_group" {
    name = "${var.project}-${var.env}-db-group"
    subnet_ids = var.private_subnets
}

resource "aws_db_instance" "ins" {
    identifier = "${var.project}-${var.env}-db"
    engine = "postgres"
    engine_version = "15.4"
    instance_class = "db.t3.medium"
    db_name = "appdb"
    username = "appuser"
    password = random_password.db.result
    db_subnet_group_name = aws_db_subnet_group.db_group.name
    vpc_security_group_ids = [var.rds_sg_id]

    multi_az = var.multi_az
    allocated_storage = 20
    storage_encrypted = true
    backup_retention_period = var.backup_days
    deletion_protection = var.deletion_protection
    skip_final_snapshot = var.deletion_protection ? false : true
    enabled_cloudwatch_logs_exports = ["postgresql"]
}

output "db_endpoints" {
    value = aws_db_instance.ins.address
}

output "secret_name" {
    value = aws_secretsmanager_secret.db.name
}

output "secret_arn" {
    value = aws_secretsmanager_secret.db.arn
}