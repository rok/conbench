# Buildkite Agent Infrastructure for Arrow Benchmarks

# Create a dedicated agent token for benchmark machines
resource "buildkite_agent_token" "benchmark_machines" {
  description = "BK agent token for Benchmark Machines on Arrow AWS account (NEW)"
}

# Store the agent token in AWS SSM Parameter Store
resource "aws_ssm_parameter" "buildkite_agent_token" {
  name        = "/buildkite/agent-token-benchmark-machines"
  description = "Buildkite Agent Token for benchmark machines"
  type        = "SecureString"
  value       = buildkite_agent_token.benchmark_machines.token

  tags = merge(
    local.common_tags,
    {
      Name = "buildkite-agent-token-benchmark-machines"
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

    # TODO: macos agents requires custom image, we can prepare it with ansible or manually
    # # AMD64 mac2.metal for macOS benchmarks
    # amd64-mac2-metal-macos = {
    #   queue                = "amd64-mac2-metal-macos"
    #   tags                 = ["arch=amd64", "os=macos", "instance=mac2-metal"]
    #   instance             = "mac2.metal"
    #   platform             = "macos"
    #   # ami                  = var.buildkite_agent_amis["amd64-macos"]
    #   min_size             = 0
    #   max_size             = 2
    #   on_demand_percentage = 100
    # }
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
    BootstrapScriptUrl                    = "https://raw.githubusercontent.com/rok/conbench/refs/heads/main/terraform/buildkite-bootstrap.sh"
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
    MinSize = each.value.min_size
    MaxSize = each.value.max_size
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
    aws_ssm_parameter.buildkite_agent_token,
    aws_iam_policy.buildkite_agent
  ]
}

# ============================================================================
# Buildkite Pipeline Management
# ============================================================================

# Pipeline configurations
locals {
  arrow_bci_pipelines = {
    arrow-bci-deploy = {
      folder                     = "deploy"
      queue                      = "amd64-m5-4xlarge-linux"
      trigger_mode               = "code"
      publish_commit_status      = true
      build_branches             = true
      build_pull_requests        = false
      skip_pull_request_builds_for_existing_commits = true
      cancel_intermediate_builds = false
    }
    arrow-bci-schedule-and-publish = {
      folder                     = "schedule_and_publish"
      queue                      = "amd64-m5-4xlarge-linux"
      trigger_mode               = "none"
      publish_commit_status      = false
      build_branches             = false
      build_pull_requests        = false
      skip_pull_request_builds_for_existing_commits = true
      cancel_intermediate_builds = true
    }
    arrow-bci-test = {
      folder                     = "test"
      queue                      = "amd64-m5-4xlarge-linux"
      trigger_mode               = "code"
      publish_commit_status      = true
      build_branches             = true
      build_pull_requests        = true
      skip_pull_request_builds_for_existing_commits = true
      cancel_intermediate_builds = false
    }
    arrow-bci-benchmark-build-test = {
      folder                     = "benchmark-test"
      queue                      = "amd64-m5-4xlarge-linux"
      trigger_mode               = "none"
      publish_commit_status      = false
      build_branches             = false
      build_pull_requests        = false
      skip_pull_request_builds_for_existing_commits = true
      cancel_intermediate_builds = false
    }
  }
}

# Arrow Benchmarks CI Pipelines
resource "buildkite_pipeline" "arrow_bci_pipelines" {
  for_each       = local.arrow_bci_pipelines
  name           = each.key
  repository     = "https://github.com/arctosalliance/arrow-benchmarks-ci.git"
  default_branch = "main"

  steps = <<-EOT
  agents:
    queue: "${each.value.queue}"
  steps:
    - label: ":pipeline: Pipeline upload"
      command: buildkite-agent pipeline upload buildkite/${each.value.folder}/pipeline.yml
  EOT

  provider_settings {
    trigger_mode                                  = each.value.trigger_mode
    publish_commit_status                         = each.value.publish_commit_status
    build_branches                                = each.value.build_branches
    build_pull_requests                           = each.value.build_pull_requests
    skip_pull_request_builds_for_existing_commits = each.value.skip_pull_request_builds_for_existing_commits
  }

  cancel_intermediate_builds = each.value.cancel_intermediate_builds
}

# Schedule for arrow-bci-schedule-and-publish pipeline - runs every 15 minutes
resource "buildkite_pipeline_schedule" "every_15_mins" {
  pipeline_id = buildkite_pipeline.arrow_bci_pipelines["arrow-bci-schedule-and-publish"].id
  label       = "Every 15 minutes"
  cronline    = "*/15 * * * *"
  branch      = buildkite_pipeline.arrow_bci_pipelines["arrow-bci-schedule-and-publish"].default_branch
  enabled     = true
}
