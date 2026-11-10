locals {
  vpc_cidrs = {
    hub     = var.hub_cidr
    spoke_a = var.spoke_a_cidr
    spoke_b = var.spoke_b_cidr
  }

  # The variable order is the subnet order. The data source only checks that
  # each name exists; it is not used to pick zones, so a new AZ cannot shift CIDRs.
  azs = var.availability_zones

  # Derived from each /16 so the plan cannot drift from docs/design-decisions.md.
  #   public  /24  netnum 0, 1, ...            -> 10.x.0.0/24, 10.x.1.0/24
  #   private /24  netnum 10, 11, ...          -> 10.x.10.0/24, 10.x.11.0/24
  #   tgw     /28  netnum 1600 + az index      -> 10.x.100.0/28, 10.x.100.16/28
  # A /28 is 16 addresses. 1600 * 16 = 25600 addresses = octet 100.
  subnets = {
    for name, cidr in local.vpc_cidrs : name => {
      public = {
        for idx, az in local.azs : az => cidrsubnet(cidr, 8, idx)
      }
      private = {
        for idx, az in local.azs : az => cidrsubnet(cidr, 8, idx + 10)
      }
      tgw = {
        for idx, az in local.azs : az => cidrsubnet(cidr, 12, 1600 + idx)
      }
    }
  }

  # Every VPC CIDR is a /16, so two of them overlap only when the network
  # address is the same. HashiCorp Terraform has no cidrcontains function.
  cidrs_do_not_overlap = (
    cidrhost(var.hub_cidr, 0) != cidrhost(var.spoke_a_cidr, 0)
    && cidrhost(var.hub_cidr, 0) != cidrhost(var.spoke_b_cidr, 0)
    && cidrhost(var.spoke_a_cidr, 0) != cidrhost(var.spoke_b_cidr, 0)
  )

  reachable = {
    for src in keys(local.vpc_cidrs) : src => [
      for dst in keys(local.vpc_cidrs) : dst
      if dst != src && (src == "hub" || dst == "hub" || var.allow_spoke_to_spoke)
    ]
  }

  # Keys are static strings. Private route tables are indexed by position in
  # availability_zones so the key does not depend on a route table ID.
  inter_vpc_routes = merge(flatten([
    for src, dests in local.reachable : [
      {
        for dst in dests : "${src}|public|${dst}" => {
          route_table_id = module.vpc[src].public_route_table_id
          cidr           = local.vpc_cidrs[dst]
        }
      },
      {
        for pair in setproduct(range(length(local.azs)), dests) :
        "${src}|private-${pair[0]}|${pair[1]}" => {
          route_table_id = module.vpc[src].private_route_table_ids[pair[0]]
          cidr           = local.vpc_cidrs[pair[1]]
        }
      },
    ]
  ])...)
}
