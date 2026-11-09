#!/usr/bin/env bash
# Destroy every resource in the envs/lab state file.
# This is scoped to that state. It does not search the account for other resources.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}/envs/lab"

if ! command -v terraform >/dev/null 2>&1; then
  echo "error: terraform is not on PATH" >&2
  exit 1
fi

yes=0
args=()
for arg in "$@"; do
  if [[ "${arg}" == "--yes" ]]; then
    yes=1
  else
    args+=("${arg}")
  fi
done

cat <<'EOF'
aws-netops-lab: destroying envs/lab.

This deletes the VPCs, subnets, route tables, Transit Gateway, attachments,
and inter-VPC routes recorded in this state file. An attachment that is still
present keeps billing. Destroy is complete when Terraform reports that no
resources remain.
EOF

if [[ "${yes}" -ne 1 ]]; then
  read -r -p "Type destroy to continue: " answer
  if [[ "${answer}" != "destroy" ]]; then
    echo "aborted" >&2
    exit 1
  fi
fi

terraform init -input=false
if [[ ${#args[@]} -gt 0 ]]; then
  terraform destroy -input=false -auto-approve "${args[@]}"
else
  terraform destroy -input=false -auto-approve
fi
