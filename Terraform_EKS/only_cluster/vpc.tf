# vpc.tf

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  az_count_valid = var.az_count <= 8
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(var.tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.project_name}-igw" })
}

# Create public + private subnets across AZs
resource "aws_subnet" "public" {
  for_each          = { for idx, az in local.azs : idx => az }
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, each.key)
  availability_zone = each.value
  map_public_ip_on_launch = true
  tags = merge(var.tags, {
    Name = "${var.project_name}-public-${each.value}"
    "kubernetes.io/role/elb" = 1
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  })
}

resource "aws_subnet" "private" {
  for_each          = { for idx, az in local.azs : idx => az }
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, each.key + 8)
  availability_zone = each.value
  tags = merge(var.tags, {
    Name = "${var.project_name}-private-${each.value}"
    "kubernetes.io/role/internal-elb" = 1
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.project_name}-public-rt" })
}

resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# (Optional) NAT Gateway for private subnets if you add node groups later
# Skipped for pure Fargate to avoid costs.

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0
  domain   = "vpc"
}

resource "aws_nat_gateway" "this" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = values(aws_subnet.public)[0].id
  tags          = var.tags
}

resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = var.tags
}

resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.private[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

resource "aws_route_table_association" "private_assoc" {
  for_each = var.enable_nat_gateway ? aws_subnet.private : {}
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[0].id
}


