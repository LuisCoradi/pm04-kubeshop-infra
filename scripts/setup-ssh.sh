#!/usr/bin/env bash
# Prepara a chave SSH de administração a partir do secret SSH_PRIVATE_KEY.
#
#   scripts/setup-ssh.sh public   -> imprime a chave pública (usada pelo Terraform)
#   scripts/setup-ssh.sh client   -> grava chave + ~/.ssh/config para o Ansible
set -euo pipefail

MODE="${1:-client}"
: "${SSH_PRIVATE_KEY:?defina o secret SSH_PRIVATE_KEY}"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
KEY="$HOME/.ssh/kubeshop"
umask 077
# O secret pode chegar sem a quebra de linha final; o OpenSSH exige.
printf '%s\n' "$SSH_PRIVATE_KEY" | tr -d '\r' >"$KEY"
chmod 600 "$KEY"

case "$MODE" in
  public)
    ssh-keygen -y -f "$KEY"
    ;;
  client)
    cat >"$HOME/.ssh/config" <<'EOF'
Host *
  User ubuntu
  IdentityFile ~/.ssh/kubeshop
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
  UserKnownHostsFile ~/.ssh/known_hosts_kubeshop
  ServerAliveInterval 15
  ConnectTimeout 15
EOF
    chmod 600 "$HOME/.ssh/config"
    echo "Chave SSH e ~/.ssh/config prontos." >&2
    ;;
  *)
    echo "uso: setup-ssh.sh <public|client>" >&2
    exit 2
    ;;
esac
