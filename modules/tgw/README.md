# modules/tgw

A Transit Gateway with the default association and propagation tables turned off. Every attachment is associated and propagated explicitly.

Pass one entry in `vpc_attachments` per VPC. `subnet_ids` must be the dedicated attachment subnets from `modules/vpc`, one per availability zone. `associate_route_table` and `propagate_to_route_tables` name entries in `route_table_names`.

`appliance_mode` defaults to false. Turn it on for an attachment that will host a firewall or router which must see both directions of a flow. Phase 1 does not.

```hcl
module "tgw" {
  source = "../../modules/tgw"

  name              = "netops-lab-tgw"
  amazon_side_asn   = 64512
  route_table_names = ["hub", "spoke"]

  vpc_attachments = {
    hub = {
      vpc_id                     = module.vpc["hub"].vpc_id
      subnet_ids                 = values(module.vpc["hub"].tgw_subnet_ids)
      associate_route_table      = "hub"
      propagate_to_route_tables  = ["spoke"]
    }
  }
}
```

The lab root module is the concrete hub-and-spoke policy. This module does not assume which VPCs may talk to each other.
