variable "name" {
  description = "Short name used in Name tags. Example: netops-lab-tgw."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name)) && length(var.name) <= 32
    error_message = "name must be 1-32 characters of lowercase letters, digits, and hyphens."
  }
}

variable "description" {
  description = "Transit Gateway description shown in the AWS console."
  type        = string
  default     = "Transit gateway"
}

variable "amazon_side_asn" {
  description = "Private ASN for the Transit Gateway. Reserved for a later BGP phase. Range 64512-65534 or 4200000000-4294967294."
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

variable "route_table_names" {
  description = "Transit Gateway route table names to create. Attachments reference these names. The default association and propagation tables on the gateway are disabled."
  type        = set(string)

  validation {
    condition     = length(var.route_table_names) > 0
    error_message = "Create at least one Transit Gateway route table."
  }
}

variable "vpc_attachments" {
  description = "VPC attachments. subnet_ids must be the dedicated TGW subnets, one per AZ. propagate_to_route_tables controls which route tables learn this VPC's CIDR."
  type = map(object({
    vpc_id                    = string
    subnet_ids                = list(string)
    associate_route_table     = string
    propagate_to_route_tables = list(string)
    appliance_mode            = optional(bool, false)
  }))

  validation {
    condition = alltrue([
      for attachment in var.vpc_attachments : length(attachment.subnet_ids) >= 2
    ])
    error_message = "Each VPC attachment needs at least two subnet IDs, in different availability zones."
  }
}

variable "tags" {
  description = "Extra tags merged onto resources in this module. Provider default_tags are applied by the caller."
  type        = map(string)
  default     = {}
}
