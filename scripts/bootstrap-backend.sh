#!/usr/bin/env bash
# Garante o bucket S3 que guarda o Terraform State e os backups do MongoDB.
#
# O bucket não fica no próprio Terraform porque o state não pode morar em um
# recurso gerenciado por ele mesmo. O script é idempotente: cria o bucket só
# se ele não existir e reaplica as configurações de segurança a cada execução.
#
# Saída: nome do bucket em stdout e, no GitHub Actions, em $GITHUB_OUTPUT.
set -euo pipefail

REGION="${AWS_REGION:?defina AWS_REGION}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="${TF_STATE_BUCKET:-kubeshop-${ACCOUNT_ID}-${REGION}}"

if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  echo "Bucket ${BUCKET} já existe." >&2
else
  echo "Criando bucket ${BUCKET} em ${REGION}..." >&2
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" >/dev/null
  else
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null
  fi
  aws s3api wait bucket-exists --bucket "$BUCKET"
fi

# Sem acesso público, com versionamento (histórico do state) e criptografia.
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Retenção: backups por 14 dias; versões antigas do state por 90 dias.
aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" \
  --lifecycle-configuration '{
    "Rules": [
      {
        "ID": "backups-retencao-14-dias",
        "Filter": {"Prefix": "backups/"},
        "Status": "Enabled",
        "Expiration": {"Days": 14},
        "NoncurrentVersionExpiration": {"NoncurrentDays": 1}
      },
      {
        "ID": "tfstate-versoes-antigas-90-dias",
        "Filter": {"Prefix": "tfstate/"},
        "Status": "Enabled",
        "NoncurrentVersionExpiration": {"NoncurrentDays": 90}
      }
    ]
  }'

echo "$BUCKET"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "bucket=${BUCKET}" >>"$GITHUB_OUTPUT"
fi
