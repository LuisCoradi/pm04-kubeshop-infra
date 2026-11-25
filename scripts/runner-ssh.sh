#!/usr/bin/env bash
# Libera a porta 22 da VM da aplicação apenas para o IP do runner do GitHub
# Actions enquanto a pipeline executa, e remove a regra no final.
#
#   scripts/runner-ssh.sh open  <security-group-id> <ip-da-vm>
#   scripts/runner-ssh.sh close <security-group-id>
#
# As regras temporárias têm descrição "github-actions-*" e ficam fora do
# Terraform (o security group usa regras em recursos separados), então não
# aparecem como diferença no plan.
set -euo pipefail

ACTION="${1:?uso: runner-ssh.sh <open|close> <sg-id> [ip-da-vm]}"
SG_ID="${2:?informe o security group}"
DESCRIPTION="github-actions-${GITHUB_RUN_ID:-local}"

close_rules() {
  local ids
  ids="$(aws ec2 describe-security-group-rules \
    --filters "Name=group-id,Values=${SG_ID}" \
    --query "SecurityGroupRules[?IsEgress==\`false\` && Description!=\`null\` && starts_with(Description, 'github-actions-')].SecurityGroupRuleId" \
    --output text)"
  if [ -n "$ids" ] && [ "$ids" != "None" ]; then
    # shellcheck disable=SC2086
    aws ec2 revoke-security-group-ingress --group-id "$SG_ID" --security-group-rule-ids $ids >/dev/null
    echo "Regras temporárias de SSH removidas: ${ids}" >&2
  else
    echo "Nenhuma regra temporária de SSH para remover." >&2
  fi
}

case "$ACTION" in
  open)
    VM_IP="${3:?informe o IP da VM}"
    RUNNER_IP="$(curl -fsS --max-time 10 https://checkip.amazonaws.com | tr -d '[:space:]')"
    echo "Liberando SSH para o runner ${RUNNER_IP}/32 (regra ${DESCRIPTION})..." >&2
    if ! out="$(aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
      --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${RUNNER_IP}/32,Description=${DESCRIPTION}}]" 2>&1)"; then
      if grep -q "InvalidPermission.Duplicate" <<<"$out"; then
        echo "Regra já existia." >&2
      else
        echo "$out" >&2
        exit 1
      fi
    fi
    echo "Aguardando SSH em ${VM_IP}:22..." >&2
    for _ in $(seq 1 60); do
      if nc -z -w 5 "$VM_IP" 22 2>/dev/null; then
        echo "SSH disponível." >&2
        exit 0
      fi
      sleep 5
    done
    echo "SSH não respondeu em 5 minutos." >&2
    exit 1
    ;;
  close)
    close_rules
    ;;
  *)
    echo "uso: runner-ssh.sh <open|close> <sg-id> [ip-da-vm]" >&2
    exit 2
    ;;
esac
