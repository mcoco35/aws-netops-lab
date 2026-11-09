output "transit_gateway_id" {
  description = "Transit Gateway ID."
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_arn" {
  description = "Transit Gateway ARN."
  value       = aws_ec2_transit_gateway.this.arn
}

output "route_table_ids" {
  description = "Transit Gateway route table IDs keyed by the names passed in route_table_names."
  value       = { for name, rt in aws_ec2_transit_gateway_route_table.this : name => rt.id }
}

output "vpc_attachment_ids" {
  description = "VPC attachment IDs keyed by the attachment name."
  value       = { for name, attachment in aws_ec2_transit_gateway_vpc_attachment.this : name => attachment.id }
}

output "amazon_side_asn" {
  description = "Private ASN configured on the Transit Gateway."
  value       = aws_ec2_transit_gateway.this.amazon_side_asn
}
