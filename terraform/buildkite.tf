# Buildkite Agent Infrastructure for Arrow Benchmarks

# S3 bucket for buildkite secrets and bootstrap scripts
resource "aws_s3_bucket" "buildkite_secrets" {
  bucket = "${local.cluster_name}-buildkite-secrets"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-buildkite-secrets"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "buildkite_secrets" {
  bucket = aws_s3_bucket.buildkite_secrets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "buildkite_secrets" {
  bucket = aws_s3_bucket.buildkite_secrets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Upload bootstrap script to S3
resource "aws_s3_object" "bootstrap_script" {
  bucket = aws_s3_bucket.buildkite_secrets.id
  key    = "bootstrap/setup_benchmark_machine.sh"
  source = "${path.module}/buildkite-bootstrap.sh"
  etag   = filemd5("${path.module}/buildkite-bootstrap.sh")

  server_side_encryption = "AES256"
}

# SSM Parameter for Buildkite Agent Token
resource "aws_ssm_parameter" "buildkite_agent_token" {
  name        = "/buildkite/agent-token"
  description = "Buildkite Agent Token for arrow-dev.org organization"
  type        = "SecureString"
  value       = var.buildkite_agent_token

  tags = merge(
    local.common_tags,
    {
      Name = "buildkite-agent-token"
    }
  )
}

# IAM policy for Buildkite agents
resource "aws_iam_policy" "buildkite_agent" {
  name        = "${local.cluster_name}-buildkite-agent-policy"
  description = "IAM policy for Buildkite agents"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.buildkite_secrets.arn,
          "${aws_s3_bucket.buildkite_secrets.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
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
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })

  tags = local.common_tags
}

# Buildkite Agent Stacks
locals {
  buildkite_stacks = {
    # ARM64 T4g 2xlarge for ARM benchmarks
    arm64-t4g-2xlarge-linux = {
      queue                = "arm64-t4g-2xlarge-linux"
      tags                 = ["arch=arm64", "os=linux", "instance=t4g-2xlarge"]
      instance             = "t4g.2xlarge"
      platform             = "linux"
      # ami                  = var.buildkite_agent_amis["arm64-linux"]
      min_size             = 0
      max_size             = 4
      on_demand_percentage = 100
    }

    # AMD64 M5 4xlarge for general purpose benchmarks
    amd64-m5-4xlarge-linux = {
      queue                = "amd64-m5-4xlarge-linux"
      tags                 = ["arch=amd64", "os=linux", "instance=m5-4xlarge"]
      instance             = "m5.4xlarge"
      platform             = "linux"
      # ami                  = var.buildkite_agent_amis["amd64-linux"]
      min_size             = 0
      max_size             = 4
      on_demand_percentage = 100
    }

    # AMD64 C6a 4xlarge for compute-optimized benchmarks
    amd64-c6a-4xlarge-linux = {
      queue                = "amd64-c6a-4xlarge-linux"
      tags                 = ["arch=amd64", "os=linux", "instance=c6a-4xlarge"]
      instance             = "c6a.4xlarge"
      platform             = "linux"
      # ami                  = var.buildkite_agent_amis["amd64-linux"]
      min_size             = 0
      max_size             = 4
      on_demand_percentage = 100
    }

    # AMD64 mac2.metal for macOS benchmarks
    amd64-mac2-metal-macos = {
      queue                = "amd64-mac2-metal-macos"
      tags                 = ["arch=amd64", "os=macos", "instance=mac2-metal"]
      instance             = "mac2.metal"
      platform             = "macos"
      # ami                  = var.buildkite_agent_amis["amd64-macos"]
      min_size             = 0
      max_size             = 2
      on_demand_percentage = 100
    }
  }
}

# Create CloudFormation stacks for each Buildkite agent type
resource "aws_cloudformation_stack" "buildkite_agents" {
  for_each = local.buildkite_stacks

  name = "${local.cluster_name}-buildkite-${each.key}"

  parameters = {
    VpcId = aws_vpc.main.id
    Subnets = join(",", [
      aws_subnet.public[0].id,
      aws_subnet.public[1].id
    ])
    BootstrapScriptUrl                    = "s3://${aws_s3_bucket.buildkite_secrets.bucket}/${aws_s3_object.bootstrap_script.key}"
    BuildkiteAgentTokenParameterStorePath = aws_ssm_parameter.buildkite_agent_token.name
    BuildkiteAgentTags                    = join(",", each.value.tags)
    BuildkiteQueue                        = each.value.queue
    # ImageId                               = each.value.ami
    OnDemandPercentage                    = each.value.on_demand_percentage
    InstanceTypes                         = each.value.instance
    InstanceRoleName                      = "${local.cluster_name}-buildkite-${each.key}-role"
    InstanceOperatingSystem               = each.value.platform
    AgentsPerInstance                     = 1
    ECRAccessPolicy                       = "full"
    ManagedPolicyARNs = join(",", [
      aws_iam_policy.buildkite_agent.arn,
      "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    ])
    MinSize       = each.value.min_size
    MaxSize       = each.value.max_size
    SecretsBucket = aws_s3_bucket.buildkite_secrets.bucket
  }

  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_NAMED_IAM",
    "CAPABILITY_AUTO_EXPAND"
  ]

  # Buildkite AWS Stack CloudFormation template
  template_url = "https://s3.amazonaws.com/buildkite-aws-stack/v6.21.0/aws-stack.yml"

  tags = merge(
    local.common_tags,
    {
      Name  = "${local.cluster_name}-buildkite-${each.key}"
      Queue = each.value.queue
    }
  )

  depends_on = [
    aws_s3_object.bootstrap_script,
    aws_ssm_parameter.buildkite_agent_token,
    aws_iam_policy.buildkite_agent
  ]
}
