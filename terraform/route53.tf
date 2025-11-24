# Route53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-hosted-zone"
    }
  )
}

# A Record for ALB (points to the load balancer)
# Note: This will be created after the ingress creates the ALB
resource "aws_route53_record" "app" {
  count   = var.create_route53_record ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    # The ALB is created by the AWS Load Balancer Controller when you apply the ingress
    # You'll need to get the ALB DNS name and zone ID after the ingress is created
    # For now, we'll output instructions on how to create this record manually
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Optional: WWW subdomain redirect
resource "aws_route53_record" "www" {
  count   = var.create_www_record ? 1 : 0
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.domain_name]
}
