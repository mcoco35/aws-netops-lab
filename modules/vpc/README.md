# modules/vpc

One VPC with public, private, and Transit Gateway attachment subnets across the availability zones you pass in.

The module creates:

- A DNS-enabled VPC and an internet gateway
- Public subnets sharing one route table with `0.0.0.0/0` to the internet gateway
- Private subnets, each with its own route table, and no default route unless NAT is enabled
- A `/28`-or-larger subnet per AZ for a Transit Gateway attachment, on a route table that does not point at the gateway
- A default security group with no ingress and no egress
- NAT gateways and EIPs only when `enable_nat_gateway` is true

Public subnets do not auto-assign public IPv4 addresses. Inter-VPC routes are not created here. The caller adds those routes after the Transit Gateway attachment exists, using `public_route_table_id` and `private_route_table_ids` (that list follows `azs`). Putting the routes in this module would cycle: the attachment needs these subnets, and the routes need the gateway.

```hcl
module "hub" {
  source = "../../modules/vpc"

  name       = "netops-lab-hub"
  cidr_block = "10.0.0.0/16"
  azs        = ["us-east-1a", "us-east-1b"]

  public_subnets = {
    "us-east-1a" = "10.0.0.0/24"
    "us-east-1b" = "10.0.1.0/24"
  }
  private_subnets = {
    "us-east-1a" = "10.0.10.0/24"
    "us-east-1b" = "10.0.11.0/24"
  }
  tgw_subnets = {
    "us-east-1a" = "10.0.100.0/28"
    "us-east-1b" = "10.0.100.16/28"
  }
}
```

`envs/lab` derives that layout from each VPC `/16`. See `docs/design-decisions.md`.
