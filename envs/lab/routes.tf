# Inter-VPC routes live in the root module. Putting them in modules/vpc would
# make the VPC module depend on the Transit Gateway, while the gateway
# attachment depends on the VPC subnets.
#
# Only reachable CIDRs are installed. With allow_spoke_to_spoke left false,
# spokes do not get a route to each other, so that traffic is not blackholed
# into a Transit Gateway route table that will not forward it.

resource "aws_route" "inter_vpc" {
  for_each = local.inter_vpc_routes

  route_table_id         = each.value.route_table_id
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = module.tgw.transit_gateway_id

  # The gateway ID exists before attachments are available. Routes to a
  # Transit Gateway are rejected until the VPC attachment is ready.
  depends_on = [module.tgw]
}
