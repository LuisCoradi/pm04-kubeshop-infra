#!/usr/bin/env bash
# Gera o inventário do Ansible e as variáveis de infraestrutura a partir dos
# outputs do Terraform (JSON "achatado": {"chave": valor}).
#
# Uso: scripts/preparar-ansible.sh <tf-outputs.json>
# Gera: ansible/inventory/hosts.yml e ansible/infra-vars.json
set -euo pipefail

OUTPUTS="${1:?uso: preparar-ansible.sh <tf-outputs.json>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

get() { jq -er --arg k "$1" '.[$k]' "$OUTPUTS"; }

APP_IP="$(get app_public_ip)"
DB_IP="$(get db_private_ip)"

mkdir -p "$ROOT/ansible/inventory"
cat >"$ROOT/ansible/inventory/hosts.yml" <<EOF
# Gerado por scripts/preparar-ansible.sh a partir do Terraform. Não editar.
all:
  vars:
    ansible_user: ubuntu
  children:
    db:
      hosts:
        kubeshop-db:
          ansible_host: ${DB_IP}
          # O banco não aceita SSH da internet: acesso pela VM da aplicação.
          ansible_ssh_common_args: "-o ProxyJump=ubuntu@${APP_IP}"
    app:
      hosts:
        kubeshop-app:
          ansible_host: ${APP_IP}
EOF

jq '{
  environment_name: .environment,
  aws_region: .region,
  db_private_ip: .db_private_ip,
  db_data_volume_id: .db_data_volume_id,
  backup_bucket: .backup_bucket,
  store_url: .store_url,
  app_public_ip: .app_public_ip
}' "$OUTPUTS" >"$ROOT/ansible/infra-vars.json"

echo "Inventário: app=${APP_IP} db=${DB_IP} (via ProxyJump)" >&2
