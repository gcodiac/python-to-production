# Staging network for the Notes application.
#
# Deliberately NAT-free - see cloud-learning/05-vpcs-subnets-routing-and-security.md.
# A NAT Gateway costs roughly $35/month plus data processing, which is the
# single largest avoidable cost in a small sandbox like this one. Instead the
# worker node sits in a public subnet with a public IP for outbound access,
# protected by security groups rather than by a private subnet.
#
#   Internet
#      |
#   [ IGW ]
#      |
#   public subnets  (AZ-a, AZ-b) -> ALB + EKS worker node
#      |
#   isolated subnets (AZ-a, AZ-b) -> RDS only, no route to the internet at all

locals {
  # Two AZs is the minimum EKS requires for a cluster, and the minimum RDS
  # requires for a DB subnet group - even though only one worker node runs.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets = [
    cidrsubnet(var.vpc_cidr, 4, 0), # 10.20.0.0/20
    cidrsubnet(var.vpc_cidr, 4, 1), # 10.20.16.0/20
  ]

  # /24s are far more than a two-instance-max database needs, but keeping the
  # arithmetic obvious matters more than conserving RFC1918 space here.
  isolated_subnets = [
    cidrsubnet(var.vpc_cidr, 8, 128), # 10.20.128.0/24
    cidrsubnet(var.vpc_cidr, 8, 129), # 10.20.129.0/24
  ]
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # Both required by EKS: nodes and Pods rely on internal DNS resolution.
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-igw"
  }
}

# --- Public subnets: ALB and the EKS worker node ---------------------------

resource "aws_subnet" "public" {
  count = length(local.public_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.public_subnets[count.index]
  availability_zone = local.azs[count.index]

  # The worker node needs outbound internet (to pull images and reach the EKS
  # control plane) and there is no NAT Gateway, so it needs a public IP.
  # Inbound access is still blocked by its security group.
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-public-${local.azs[count.index]}"

    # How the AWS Load Balancer Controller discovers where to place a
    # public ALB. Without this tag, Ingress creation silently fails to find
    # eligible subnets.
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Isolated subnets: RDS only -------------------------------------------

resource "aws_subnet" "isolated" {
  count = length(local.isolated_subnets)

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.isolated_subnets[count.index]
  availability_zone = local.azs[count.index]

  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-isolated-${local.azs[count.index]}"
  }
}

# No routes to the internet gateway at all: anything in these subnets can only
# talk within the VPC. This is what "isolated" means here, and it is why RDS
# genuinely cannot be reached from the internet regardless of its own settings.
resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-isolated-rt"
  }
}

resource "aws_route_table_association" "isolated" {
  count = length(aws_subnet.isolated)

  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated.id
}
