# Plans the lab with the AWS provider mocked. This checks the CIDR derivation
# and that inter-VPC routes can be planned without credentials or a real account.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b"]
      state = "available"
    }
  }
}

run "default_cidr_plan" {
  command = plan

  assert {
    condition     = output.cidr_plan.hub.public["us-east-1a"] == "10.0.0.0/24"
    error_message = "Hub public subnet in us-east-1a should be 10.0.0.0/24."
  }

  assert {
    condition     = output.cidr_plan.hub.public["us-east-1b"] == "10.0.1.0/24"
    error_message = "Hub public subnet in us-east-1b should be 10.0.1.0/24."
  }

  assert {
    condition     = output.cidr_plan.hub.private["us-east-1a"] == "10.0.10.0/24"
    error_message = "Hub private subnet in us-east-1a should be 10.0.10.0/24."
  }

  assert {
    condition     = output.cidr_plan.hub.tgw["us-east-1b"] == "10.0.100.16/28"
    error_message = "Hub TGW subnet in us-east-1b should be 10.0.100.16/28."
  }

  assert {
    condition     = output.cidr_plan.spoke_a.tgw["us-east-1a"] == "10.1.100.0/28"
    error_message = "Spoke A TGW subnet should follow the spoke /16."
  }

  assert {
    condition     = output.cidr_plan.spoke_b.private["us-east-1b"] == "10.2.11.0/24"
    error_message = "Spoke B private subnet in the second AZ should be 10.2.11.0/24."
  }

  assert {
    condition     = output.allow_spoke_to_spoke == false
    error_message = "Spoke-to-spoke routing should be off by default."
  }
}

run "overlapping_cidrs_fail" {
  command = plan

  variables {
    spoke_a_cidr = "10.0.0.0/16"
  }

  expect_failures = [check.cidr_plan]
}
