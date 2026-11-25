#!/usr/bin/env bash
# Teste de fora para dentro (a partir do runner, como um usuário):
# página da loja, saúde da API com o banco, catálogo e versão implantada.
# Não cria pedidos.
#
# Uso: scripts/smoke-externo.sh <url-da-loja> [versao-esperada]
set -euo pipefail

URL="${1:?uso: smoke-externo.sh <url> [versao]}"
URL="${URL%/}"
EXPECTED="${2:-}"

echo "Aguardando ${URL}/api/health/ready..."
for i in $(seq 1 36); do
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "${URL}/api/health/ready" || true)"
  [ "$code" = "200" ] && break
  echo "  tentativa ${i}: HTTP ${code}"
  sleep 5
done

curl -fsS --max-time 10 "${URL}/" | grep -q "KubeShop" \
  && echo "OK  página inicial"
ready="$(curl -fsS --max-time 10 "${URL}/api/health/ready")"
echo "OK  saúde: ${ready}"
total="$(curl -fsS --max-time 10 "${URL}/api/products" | jq '.products | length')"
[ "$total" -gt 0 ] && echo "OK  catálogo: ${total} produtos"
version="$(curl -fsS --max-time 10 "${URL}/api/info" | jq -r .version)"
echo "OK  versão em execução: ${version}"

if [ -n "$EXPECTED" ] && [ "$version" != "$EXPECTED" ]; then
  echo "ERRO: esperado ${EXPECTED}, em execução ${version}" >&2
  exit 1
fi
