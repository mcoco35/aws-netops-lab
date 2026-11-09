# Design decisions

Phase 1 is the network foundation for a single-region lab: a hub VPC, two spoke VPCs, and a Transit Gateway. Later phases add routers, a Python ops CLI, and CloudWatch. Those are not built here.

## Transit Gateway instead of VPC peering

Three VPCs need three peering connections, and none of them forward. A packet from spoke A to spoke B cannot transit the hub over peering, and every new VPC adds a route on every peer. That does not survive the later phases, where the hub is the place a router or inspection path would sit, and where routing policy has to change without rebuilding the mesh.

A Transit Gateway is a regional router with its own route tables. Attachments associate to a table, and propagations decide which CIDRs that table learns. Hub-and-spoke versus spoke-to-spoke is a route-table change, not a new mesh. The gateway also has a private ASN (`amazon_side_asn`, default 64512) so a later BGP phase has somewhere to peer. Phase 1 does not run BGP.

Peering is the cheaper way to connect three VPCs. It has no hourly attachment charge. This lab pays the Transit Gateway rate on purpose, and the README cost section says to destroy it when it is not in use. The module disables the default association and propagation tables and disables auto-accept of shared attachments, so nothing lands in the gateway unless this configuration names it.

## CIDR plan

Each VPC is an IPv4 `/16`. Subnets are derived in `envs/lab/locals.tf` from that prefix, so a caller who changes a VPC CIDR keeps the same shape. The default zones are `us-east-1a` and `us-east-1b`, passed in `availability_zones` rather than "the first N zones AWS returns." A new zone in the region then cannot move a subnet. A third name, when you supply one, continues the same offsets. The names have to exist in `aws_region`; a `check` block compares them to a zone-name filter on `aws_availability_zones`.

`cidrsubnet(prefix, 12, 1600)` is the first TGW subnet. A `/28` is 16 addresses, and `1600 * 16` lands on octet 100.

| VPC | CIDR | Public AZ1 | Public AZ2 | Private AZ1 | Private AZ2 | TGW AZ1 | TGW AZ2 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Hub | 10.0.0.0/16 | 10.0.0.0/24 | 10.0.1.0/24 | 10.0.10.0/24 | 10.0.11.0/24 | 10.0.100.0/28 | 10.0.100.16/28 |
| Spoke A | 10.1.0.0/16 | 10.1.0.0/24 | 10.1.1.0/24 | 10.1.10.0/24 | 10.1.11.0/24 | 10.1.100.0/28 | 10.1.100.16/28 |
| Spoke B | 10.2.0.0/16 | 10.2.0.0/24 | 10.2.1.0/24 | 10.2.10.0/24 | 10.2.11.0/24 | 10.2.100.0/28 | 10.2.100.16/28 |

The `/16` requirement is deliberate. The lab is not a general IPAM. Free space inside each VPC (for example `10.x.2.0/24` through `10.x.9.0/24`, and `10.x.12.0/24` upward except the `10.x.100.0/24` block used by the attachment subnets) is left for later workloads. A `check` block rejects overlapping VPC CIDRs. The VPC module rejects subnet CIDRs that fall outside the VPC or overlap each other.

IPv6 is out of scope.

## Subnet roles

Public subnets share a route table with `0.0.0.0/0` via an internet gateway. The gateway has no hourly charge. `map_public_ip_on_launch` is false, so a future instance does not pick up a billable public IPv4 address unless that instance asks for one.

Private subnets have one route table per AZ. With NAT left off, they have no default route. They can still reach other VPCs when an inter-VPC route is installed, because that traffic goes to the Transit Gateway and does not need NAT.

Transit Gateway subnets are a `/28` per AZ and nothing else. AWS requires a dedicated subnet for the attachment ENIs. Their route table has only the VPC local route. A route from the attachment subnet back to the gateway loops traffic, so inter-VPC routes are added only to the public and private tables (`workload_route_table_ids`).

## Routing policy

Two Transit Gateway route tables, `hub` and `spoke`:

| Attachment | Associated table | Propagates to |
| --- | --- | --- |
| Hub | hub | spoke |
| Spoke A | spoke | hub |
| Spoke B | spoke | hub |

VPC workload route tables point at the gateway only for CIDRs that policy actually forwards:

- Hub route tables: spoke A and spoke B
- Spoke route tables: the hub

Spoke A has no route to spoke B. That is the default, controlled by `allow_spoke_to_spoke` (false). Setting it to true propagates each spoke into the spoke route table and adds the matching VPC routes. Spoke-to-spoke through an appliance in the hub is not built. That would need a router in the hub and appliance mode on the hub attachment. The TGW module accepts `appliance_mode` per attachment and leaves it false.

DNS support and security-group referencing are enabled on the gateway and on each attachment. Both are free and are the settings a later instance phase will want. No security groups are created beyond the default group, which is adopted and emptied.

## What Phase 1 leaves out

- **NAT gateways.** `enable_nat_gateway` defaults to false. When set, `single_nat_gateway` defaults to true so a test does not create one NAT per AZ. Private egress then depends on the first AZ.
- **EC2, FRR, and BGP.** No always-on compute. The ASN is only reserved.
- **VPC flow logs.** Checkov CKV2_AWS_11 is skipped on the VPC. A log group with no instances is a small charge, but flow logs belong with the CloudWatch phase rather than half-configured here.
- **Remote state.** State is a gitignored local file. `envs/lab/backend.tf` has a commented S3 backend that uses `use_lockfile` (Terraform 1.10 or newer). Uncomment it and run `terraform init -migrate-state` when you want a shared bucket. Do not commit a real bucket name.
- **Network firewall, VPC endpoints, IPv6, and cross-region peering.** Not required to prove the route tables.

## Cost consequence

The Transit Gateway is the billable object in the default stack. VPCs, subnets, route tables, and internet gateways have no hourly charge. The README walks the published attachment rate and tells you to destroy the lab and to set an AWS Budgets alert. A destroyed lab is the idle state. An applied gateway with no instances is not idle.
