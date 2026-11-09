output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC IPv4 CIDR."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs keyed by availability zone."
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "private_subnet_ids" {
  description = "Private subnet IDs keyed by availability zone."
  value       = { for az, subnet in aws_subnet.private : az => subnet.id }
}

output "tgw_subnet_ids" {
  description = "Transit Gateway attachment subnet IDs keyed by availability zone."
  value       = { for az, subnet in aws_subnet.tgw : az => subnet.id }
}

output "public_route_table_id" {
  description = "Route table for the public subnets. Inter-VPC routes for public workloads go here."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Private route table IDs in the same order as var.azs. The list length is known at plan time."
  value       = [for az in var.azs : aws_route_table.private[az].id]
}

output "workload_route_table_ids" {
  description = "Public and private route table IDs that should receive inter-VPC routes, keyed by public and private-<az>. The TGW attachment route table is excluded."
  value = merge(
    { public = aws_route_table.public.id },
    { for az, rt in aws_route_table.private : "private-${az}" => rt.id },
  )
}

output "tgw_route_table_id" {
  description = "Route table associated with the Transit Gateway subnets. It has no route to the Transit Gateway."
  value       = aws_route_table.tgw.id
}

output "internet_gateway_id" {
  description = "Internet gateway ID. The gateway has no hourly charge."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs keyed by availability zone. Empty when enable_nat_gateway is false."
  value       = { for az, nat in aws_nat_gateway.this : az => nat.id }
}
