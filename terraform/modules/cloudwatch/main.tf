variable "project" {}
variable "env" {}
variable "alert_email" {}
variable "db_id" {}

resource "aws_cloudwatch_log_group" "app" {
    name = "/app/${var.project}/${var.env}"
    retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "rds" {
    name = "/rds/instance/${var.project}-${var.env}"
    retention_in_days = 14
}

resource "aws_sns_topic" "alert" {
    name = "${var.project}-${var.env}-alert"
}

resource "aws_sns_topic_subscription" "emailalert" {
    topic_arn = aws_sns_topic.alert.arn
    protocol = "email"
    endpoint = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
    alarm_name = "${var.project}-${var.env}-rds-cpu-high-usage"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = 2
    metric_name = "CPUUtilization"
    namespace = "AWS/RDS"
    period = 60
    statistic = "Average"
    threshold = 80
    alarm_actions = [aws_sns_topic.alert.arn]
    dimensions = {DBInstanceIdentifier = var.db_id}  
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
    alarm_name = "${var.project}-${var.env}-rds-low-storage"
    comparison_operator = "LessThanThreshold"
    evaluation_periods = 1
    metric_name = "FreeStorageSpace"
    namespace = "AWS/RDS"
    period = 300
    statistic = "Average"
    threshold = 5368709120
    alarm_actions = [aws_sns_topic.alert.arn]
    dimensions = {DBInstanceIdentifier = var.db_id}  
}