locals {
  propagations = merge([
    for attachment_key, attachment in var.vpc_attachments : {
      for route_table in attachment.propagate_to_route_tables :
      "${attachment_key}:${route_table}" => {
        attachment_key = attachment_key
        route_table    = route_table
      }
    }
  ]...)

  attachment_targets_known = alltrue([
    for attachment in var.vpc_attachments : (
      contains(var.route_table_names, attachment.associate_route_table)
      && alltrue([
        for route_table in attachment.propagate_to_route_tables : contains(var.route_table_names, route_table)
      ])
    )
  ])
}

resource "aws_ec2_transit_gateway" "this" {
  description                        = var.description
  amazon_side_asn                    = var.amazon_side_asn
  default_route_table_association    = "disable"
  default_route_table_propagation    = "disable"
  auto_accept_shared_attachments     = "disable"
  dns_support                        = "enable"
  vpn_ecmp_support                   = "enable"
  multicast_support                  = "disable"
  security_group_referencing_support = "enable"

  tags = merge(var.tags, {
    Name = var.name
  })

  lifecycle {
    precondition {
      condition     = local.attachment_targets_known
      error_message = "Each attachment must associate and propagate only to names in route_table_names."
    }
  }
}

resource "aws_ec2_transit_gateway_route_table" "this" {
  for_each = var.route_table_names

  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-rt-${each.key}"
  })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = var.vpc_attachments

  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = each.value.vpc_id
  subnet_ids         = each.value.subnet_ids

  appliance_mode_support                          = each.value.appliance_mode ? "enable" : "disable"
  dns_support                                     = "enable"
  ipv6_support                                    = "disable"
  security_group_referencing_support              = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(var.tags, {
    Name = "${var.name}-${replace(each.key, "_", "-")}"
  })
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each = var.vpc_attachments

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.value.associate_route_table].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each = local.propagations

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[each.value.attachment_key].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[each.value.route_table].id
}
