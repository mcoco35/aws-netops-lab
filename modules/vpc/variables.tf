variable "name" {
  description = "Short name used in Name tags. Example: netops-lab-hub."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name)) && length(var.name) <= 32
    error_message = "name must be 1-32 characters of lowercase letters, digits, and hyphens."
  }
}

variable "cidr_block" {
  description = "IPv4 CIDR for the VPC. Subnet CIDRs passed in must fit inside it."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid IPv4 CIDR."
  }
}

variable "azs" {
  description = "Availability zones, in order. At least two. Keys of the subnet maps must match this set."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2 && length(var.azs) == length(distinct(var.azs))
    error_message = "Provide at least two distinct availability zones."
  }
}

variable "public_subnets" {
  description = "Map of availability zone to public subnet CIDR. These route 0.0.0.0/0 to the internet gateway."
  type        = map(string)
}

variable "private_subnets" {
  description = "Map of availability zone to private subnet CIDR. No default route unless NAT is enabled."
  type        = map(string)
}

variable "tgw_subnets" {
  description = "Map of availability zone to dedicated Transit Gateway attachment subnet CIDR. Use a /28 or larger in each AZ. These subnets are not given a route to the Transit Gateway."
  type        = map(string)
}

variable "enable_nat_gateway" {
  description = "Create NAT gateways for private subnet egress. Leave false unless a workload needs outbound internet. NAT is billed hourly."
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "When NAT is enabled, create one NAT gateway in the first AZ instead of one per AZ. Cheaper, and a single AZ failure blackholes private egress."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Extra tags merged onto resources in this module. Provider default_tags are applied by the caller."
  type        = map(string)
  default     = {}
}
