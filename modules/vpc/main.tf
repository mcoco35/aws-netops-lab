locals {
  nat_azs = var.enable_nat_gateway ? toset(
    var.single_nat_gateway ? [var.azs[0]] : var.azs
  ) : toset([])

  subnet_cidrs = concat(
    values(var.public_subnets),
    values(var.private_subnets),
    values(var.tgw_subnets),
  )

  subnet_keys_match_azs = (
    toset(var.azs) == toset(keys(var.public_subnets))
    && toset(var.azs) == toset(keys(var.private_subnets))
    && toset(var.azs) == toset(keys(var.tgw_subnets))
  )

  # HashiCorp Terraform has no cidrcontains. A child CIDR is inside a parent
  # when it is the same size or smaller and its network address, masked to the
  # parent prefix, equals the parent network. cidrhost(prefix, 0) does that mask.
  # The ternary guards invalid strings: && does not short-circuit.
  subnets_fit_vpc = alltrue([
    for cidr in local.subnet_cidrs :
    can(cidrhost(cidr, 0)) ? (
      split("/", cidr)[0] == cidrhost(cidr, 0)
      && tonumber(split("/", cidr)[1]) >= tonumber(split("/", var.cidr_block)[1])
      && cidrhost("${cidrhost(cidr, 0)}/${split("/", var.cidr_block)[1]}", 0) == cidrhost(var.cidr_block, 0)
    ) : false
  ])

  subnets_do_not_overlap = local.subnets_fit_vpc ? alltrue(flatten([
    for i, left in local.subnet_cidrs : [
      for j, right in local.subnet_cidrs : i == j || !(
        (
          tonumber(split("/", right)[1]) >= tonumber(split("/", left)[1])
          && cidrhost("${cidrhost(right, 0)}/${split("/", left)[1]}", 0) == cidrhost(left, 0)
        )
        || (
          tonumber(split("/", left)[1]) >= tonumber(split("/", right)[1])
          && cidrhost("${cidrhost(left, 0)}/${split("/", right)[1]}", 0) == cidrhost(right, 0)
        )
      )
    ]
  ])) : false

  tgw_subnets_are_large_enough = alltrue([
    for cidr in values(var.tgw_subnets) :
    can(regex("^[^/]+/([0-9]+)$", cidr)) ? tonumber(split("/", cidr)[1]) <= 28 : false
  ])
}

resource "aws_vpc" "this" {
  #checkov:skip=CKV2_AWS_11:VPC flow logs are deferred to Phase 4 so an idle lab does not create a log group or ingestion path. See docs/design-decisions.md.
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"

  tags = merge(var.tags, {
    Name = var.name
  })

  lifecycle {
    precondition {
      condition     = local.subnet_keys_match_azs
      error_message = "public_subnets, private_subnets, and tgw_subnets must use exactly the AZ names in azs."
    }

    precondition {
      condition     = local.subnets_fit_vpc && local.subnets_do_not_overlap
      error_message = "Subnet CIDRs must be valid, non-overlapping, and contained in cidr_block."
    }

    precondition {
      condition     = local.tgw_subnets_are_large_enough
      error_message = "Each TGW subnet must be a /28 or larger (prefix length 28 or less). AWS rejects smaller attachment subnets."
    }
  }
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  # No ingress and no egress. AWS's default SG allows all egress and self-ingress;
  # adopting it here removes those rules. Nothing in Phase 1 uses this group.
  tags = merge(var.tags, {
    Name = "${var.name}-default"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-public-${each.key}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-private-${each.key}"
    Tier = "private"
  })
}

resource "aws_subnet" "tgw" {
  for_each = var.tgw_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-${each.key}"
    Tier = "tgw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-public"
    Tier = "public"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = var.private_subnets

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-private-${each.key}"
    Tier = "private"
  })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# Attachment subnets stay on a route table with only the implicit local route.
# A route from these subnets back to the Transit Gateway loops traffic.
resource "aws_route_table" "tgw" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-tgw"
    Tier = "tgw"
  })
}

resource "aws_route_table_association" "tgw" {
  for_each = aws_subnet.tgw

  subnet_id      = each.value.id
  route_table_id = aws_route_table.tgw.id
}

resource "aws_eip" "nat" {
  for_each = local.nat_azs

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-nat-${each.key}"
  })
}

resource "aws_nat_gateway" "this" {
  for_each = local.nat_azs

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.tags, {
    Name = "${var.name}-nat-${each.key}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "private_nat" {
  for_each = var.enable_nat_gateway ? aws_route_table.private : {}

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? var.azs[0] : each.key].id
}
