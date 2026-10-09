# Capa cluster · Infraestructura efímera (TTL 72 h): VPC, EKS, ECR y guardrail de costos.
# Ciclo de vida: scripts/up-ephemeral.sh y scripts/teardown-ephemeral.sh.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = var.cluster_name
  cidr = "10.40.0.0/16"
  azs  = local.azs

  private_subnets = ["10.40.0.0/19", "10.40.32.0/19"]
  public_subnets  = ["10.40.96.0/24", "10.40.97.0/24"]

  # Un solo NAT: suficiente para 72 h y la mitad del costo de uno por AZ
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Descubrimiento de subredes para los balanceadores que crea Kubernetes (NLB de Grafana)
  public_subnet_tags  = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = "1" }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.29"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  # API pública restringida a las IPs autorizadas
  endpoint_public_access                   = true
  endpoint_public_access_cidrs             = var.admin_cidrs
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # FinOps: sin logs del control plane en CloudWatch para un entorno de 72 h
  enabled_log_types           = []
  create_cloudwatch_log_group = false

  addons = {
    vpc-cni    = { before_compute = true, most_recent = true }
    kube-proxy = { most_recent = true }
    coredns    = { most_recent = true }
    aws-ebs-csi-driver = {
      most_recent = true
      # Los volúmenes que crea Kubernetes también llevan el TTL: el barrido del teardown los encuentra
      configuration_values = jsonencode({ controller = { extraVolumeTags = local.ephemeral_tags } })
    }
  }

  eks_managed_node_groups = {
    platform = {
      ami_type       = "AL2023_ARM_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type

      min_size     = var.node_count
      max_size     = var.node_count + 1
      desired_size = var.node_count
      disk_size    = 40

      # El driver EBS CSI usa el rol del nodo vía IMDSv2: requiere hop limit 2 (el default del módulo es 1)
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }

      iam_role_additional_policies = {
        ebs_csi = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }

      labels = { workload = "platform" }
    }
  }
}

resource "aws_ecr_repository" "images" {
  for_each = toset(["payments-qr", "traffic-generator"])

  name                 = "bancoplus/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  # Entorno efímero: el destroy elimina el repositorio aunque tenga imágenes
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_budgets_budget" "ephemeral" {
  count = var.budget_alert_email == "" ? 0 : 1

  name         = "${var.cluster_name}-ttl-72h"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = [
      { type = "ACTUAL", threshold = 50 },
      { type = "ACTUAL", threshold = 80 },
      { type = "FORECASTED", threshold = 100 },
    ]
    content {
      comparison_operator        = "GREATER_THAN"
      notification_type          = notification.value.type
      threshold                  = notification.value.threshold
      threshold_type             = "PERCENTAGE"
      subscriber_email_addresses = [var.budget_alert_email]
    }
  }
}

# FinOps: endpoint de gateway para S3 sin costo. Las capas de imágenes de ECR se descargan desde S3:
# con el endpoint ese tráfico no atraviesa el NAT Gateway (US$0,045/GB procesado).
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = { Name = "${var.cluster_name}-s3" }
}

# FinOps: costo del entorno visible en Cost Explorer por Environment, TTL, Owner y Purpose
resource "aws_ce_cost_allocation_tag" "ephemeral" {
  for_each = var.cost_allocation_tags_enabled ? local.ephemeral_tags : {}

  tag_key = each.key
  status  = "Active"
}
