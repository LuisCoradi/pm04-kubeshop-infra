#!/usr/bin/env bash
# terraform init com o backend S3 do ambiente informado.
# Uso: scripts/tf-init.sh <dev|homolog|prod> <bucket>
set -euo pipefail

ENVIRONMENT="${1:?uso: tf-init.sh <ambiente> <bucket>}"
BUCKET="${2:?uso: tf-init.sh <ambiente> <bucket>}"
REGION="${AWS_REGION:?defina AWS_REGION}"

cd "$(dirname "$0")/../terraform"
terraform init -input=false -reconfigure \
  -backend-config="bucket=${BUCKET}" \
  -backend-config="key=tfstate/${ENVIRONMENT}/terraform.tfstate" \
  -backend-config="region=${REGION}"
