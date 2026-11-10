output "aws_region" {
  description = "Region the lab was created in."
  value       = var.aws_region
}

output "availability_zones" {
  description = "Availability zones selected for every VPC."
  value       = local.azs
}

output "cidr_plan" {
  description = "Subnet CIDRs derived for each VPC, keyed by availability zone."
  value       = local.subnets
}

output "vpc_ids" {
  description = "VPC IDs keyed by hub, spoke_a, and spoke_b."
  value       = { for name, vpc in module.vpc : name => vpc.vpc_id }
}

output "transit_gateway_id" {
  description = "Transit Gateway ID. Attachments on this gateway are the hourly cost of the lab."
  value       = module.tgw.transit_gateway_id
}

output "transit_gateway_route_table_ids" {
  description = "Transit Gateway route table IDs keyed by hub and spoke."
  value       = module.tgw.route_table_ids
}

output "vpc_attachment_ids" {
  description = "Transit Gateway VPC attachment IDs keyed by VPC name."
  value       = module.tgw.vpc_attachment_ids
}

output "allow_spoke_to_spoke" {
  description = "Whether spoke A and spoke B are routed to each other."
  value       = var.allow_spoke_to_spoke
}
