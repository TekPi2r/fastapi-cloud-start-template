# ALB 5xx spikes
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name}-alb-5xx"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }
  treat_missing_data = "notBreaching"
  tags               = local.tags
}

# Any unhealthy targets
resource "aws_cloudwatch_metric_alarm" "tg_unhealthy" {
  alarm_name          = "${local.name}-tg-unhealthy"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions = {
    TargetGroup  = aws_lb_target_group.app.arn_suffix
    LoadBalancer = aws_lb.app.arn_suffix
  }
  treat_missing_data = "notBreaching"
  tags               = local.tags
}
