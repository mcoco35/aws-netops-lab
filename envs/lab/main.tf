data "aws_availability_zones" "selected" {
  state = "available"

  filter {
    name   = "zone-name"
    values = var.availability_zones
  }
}

check "cidr_plan" {
  assert {
    condition     = local.cidrs_do_not_overlap
    error_message = "hub_cidr, spoke_a_cidr, and spoke_b_cidr must not overlap."
  }
}

check "availability_zones_exist" {
  assert {
    condition     = length(data.aws_availability_zones.selected.names) == length(var.availability_zones)
    error_message = "Every name in availability_zones must be an available zone in aws_region."
  }
}

module "vpc" {
  source   = "../../modules/vpc"
  for_each = local.vpc_cidrs

  name               = "${var.name_prefix}-${replace(each.key, "_", "-")}"
  cidr_block         = each.value
  azs                = local.azs
  public_subnets     = local.subnets[each.key].public
  private_subnets    = local.subnets[each.key].private
  tgw_subnets        = local.subnets[each.key].tgw
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  tags = {
    VpcRole = each.key == "hub" ? "hub" : "spoke"
  }
}

module "tgw" {
  source = "../../modules/tgw"

  name            = "${var.name_prefix}-tgw"
  description     = "Hub-and-spoke transit for the aws-netops-lab isolated region."
  amazon_side_asn = var.amazon_side_asn
  route_table_names = toset([
    "hub",
    "spoke",
  ])

  vpc_attachments = {
    for name, vpc in module.vpc : name => {
      vpc_id = vpc.vpc_id
      subnet_ids = [
        for az in local.azs : vpc.tgw_subnet_ids[az]
      ]
      associate_route_table = name == "hub" ? "hub" : "spoke"
      propagate_to_route_tables = name == "hub" ? ["spoke"] : (
        var.allow_spoke_to_spoke ? ["hub", "spoke"] : ["hub"]
      )
    }
  }

  tags = {
    Role = "transit"
  }
}
