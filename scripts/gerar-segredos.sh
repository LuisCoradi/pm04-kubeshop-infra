#!/usr/bin/env bash
# Gera a chave SSH e as senhas do MongoDB e grava direto como Secrets do
# repositório no GitHub (precisa do GitHub CLI autenticado: gh auth login).
# As senhas não aparecem na tela nem ficam em arquivo.
#
# Uso (na raiz do repositório): scripts/gerar-segredos.sh
set -euo pipefail

command -v gh >/dev/null || { echo "Instale o GitHub CLI (gh)." >&2; exit 1; }
command -v ssh-keygen >/dev/null || { echo "ssh-keygen não encontrado." >&2; exit 1; }
command -v openssl >/dev/null || { echo "openssl não encontrado." >&2; exit 1; }

KEY="$HOME/.ssh/kubeshop-pm04"
if [ ! -f "$KEY" ]; then
  mkdir -p "$HOME/.ssh"
  ssh-keygen -t ed25519 -N "" -C "kubeshop-pm04" -f "$KEY" >/dev/null
  echo "Chave SSH criada em ${KEY} (guarde para acesso manual de emergência)."
fi
gh secret set SSH_PRIVATE_KEY <"$KEY"

for name in MONGO_ROOT_PASSWORD MONGO_APP_PASSWORD; do
  if gh secret list --json name -q '.[].name' | grep -qx "$name"; then
    echo "${name} já existe; mantido (as senhas valem desde a criação do banco)."
  else
    openssl rand -hex 24 | gh secret set "$name"
    echo "${name} criado."
  fi
done

echo
echo "Falta cadastrar as credenciais da AWS:"
echo "  gh secret set AWS_ACCESS_KEY_ID"
echo "  gh secret set AWS_SECRET_ACCESS_KEY"
