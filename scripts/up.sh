#!/usr/bin/env bash
# Create or update the Phase 1 lab in envs/lab.
# Transit Gateway VPC attachments are billed per hour until destroy.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}/envs/lab"

if ! command -v terraform >/dev/null 2>&1; then
  echo "error: terraform is not on PATH" >&2
  exit 1
fi

cat <<'EOF'
aws-netops-lab: applying envs/lab.

Phase 1 creates three VPCs and a Transit Gateway. It does not create NAT
gateways or EC2 instances unless you set enable_nat_gateway=true.

Transit Gateway VPC attachments are billed for each hour they exist, including
partial hours. Destroy the lab with `make destroy` when you are done. Set an
AWS Budgets alert before you leave the stack applied. Rates are in the README.
EOF

terraform init -input=false
terraform apply -input=false -auto-approve "$@"
