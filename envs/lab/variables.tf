variable "aws_region" {
  description = "AWS region for the lab. Availability zones are selected from this region."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d+$", var.aws_region))
    error_message = "aws_region must look like a region name, for example us-east-1."
  }
}

variable "environment" {
  description = "Value of the Environment tag applied via provider default_tags."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment)) && length(var.environment) <= 32
    error_message = "environment must be 1-32 characters of lowercase letters, digits, and hyphens."
  }
}

variable "name_prefix" {
  description = "Prefix for Name tags. The hub VPC becomes <prefix>-hub."
  type        = string
  default     = "netops-lab"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix)) && length(var.name_prefix) <= 20
    error_message = "name_prefix must be 1-20 characters of lowercase letters, digits, and hyphens."
  }
}

variable "availability_zones" {
  description = "Availability zone names used by every VPC, in order. Pin these. The default is the us-east-1 pair. If you change aws_region, set zones that exist in that region. The CIDR plan supports 2 or 3 zones."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition = (
      length(var.availability_zones) >= 2
      && length(var.availability_zones) <= 3
      && length(var.availability_zones) == length(distinct(var.availability_zones))
    )
    error_message = "Provide 2 or 3 distinct availability zone names."
  }
}

variable "hub_cidr" {
  description = "IPv4 /16 for the hub VPC. Subnet layout is derived in locals.tf."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrsubnet(var.hub_cidr, 12, 1600)) && endswith(var.hub_cidr, "/16")
    error_message = "hub_cidr must be a valid IPv4 /16 network address."
  }
}

variable "spoke_a_cidr" {
  description = "IPv4 /16 for spoke A. Must not overlap the hub or spoke B."
  type        = string
  default     = "10.1.0.0/16"

  validation {
    condition     = can(cidrsubnet(var.spoke_a_cidr, 12, 1600)) && endswith(var.spoke_a_cidr, "/16")
    error_message = "spoke_a_cidr must be a valid IPv4 /16 network address."
  }
}

variable "spoke_b_cidr" {
  description = "IPv4 /16 for spoke B. Must not overlap the hub or spoke A."
  type        = string
  default     = "10.2.0.0/16"

  validation {
    condition     = can(cidrsubnet(var.spoke_b_cidr, 12, 1600)) && endswith(var.spoke_b_cidr, "/16")
    error_message = "spoke_b_cidr must be a valid IPv4 /16 network address."
  }
}

variable "enable_nat_gateway" {
  description = "Create NAT gateways in each VPC so private subnets have a default route. Off by default because each NAT gateway is billed hourly."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "When NAT is enabled, use one NAT gateway per VPC (first AZ) instead of one per AZ."
  type        = bool
  default     = true
}

variable "allow_spoke_to_spoke" {
  description = "Route spoke A and spoke B to each other through the Transit Gateway. Off by default: spokes can reach the hub, and the hub can reach both spokes."
  type        = bool
  default     = false
}

variable "amazon_side_asn" {
  description = "Private ASN on the Transit Gateway. Unused until a later BGP phase."
  type        = number
  default     = 64512

  validation {
    condition = (
      var.amazon_side_asn >= 64512 && var.amazon_side_asn <= 65534
      ) || (
      var.amazon_side_asn >= 4200000000 && var.amazon_side_asn <= 4294967294
    )
    error_message = "amazon_side_asn must be a private ASN in 64512-65534 or 4200000000-4294967294."
  }
}
