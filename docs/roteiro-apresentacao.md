# Roteiro da apresentação

Antes do dia: imagens `1.0.0` e `1.1.0` publicadas (workflow **0. App** duas vezes) e as
evidências já coletadas (incluindo uma execução **automática** do backup das 03:00, que exige
o ambiente ligado de um dia para o outro). Depois, destruir o `dev` para a criação do zero
acontecer ao vivo. A criação leva ~8–10 min: rode o
cenário 1 no começo e explique a arquitetura enquanto ele executa.

## Cenário 1 — Criação inicial

**1. Deploy**: `environment=dev`, `instance_name=vm-pm04`, `instance_type=t3.micro`,
`db_instance_type=t3.micro`, `docker_tag=1.0.0`, `update_os=false`, `extra_packages=htop`.

Mostrar:
- Terraform: `Plan: N to add, 0 to change, 0 to destroy` e o apply criando VPC, SGs, 2 VMs, IP elástico, volume.
- Ansible: cloud-init → atualizações pendentes (só verificadas) → pacotes → Docker instalado → volume montado → MongoDB `healthy` → backup agendado → API e frontend `1.0.0` → Caddy → verificação.
- Teste externo: página, saúde, catálogo e versão `1.0.0`.
- Abrir o endereço no navegador (de preferência no celular), criar um pedido e recarregar.

## Cenário 2 — Atualização do ambiente

**1. Deploy** com: `instance_type=t3.small`, `docker_tag=1.1.0`, `update_os=true`, `extra_packages=htop,git`.

Mostrar:
- Terraform: `aws_instance.app will be updated in-place` (instance_type) e `Plan: 0 to add, 1 to change, 0 to destroy`. Nada é recriado; o IP elástico não muda.
- Ansible: atualizações do SO aplicadas, `git` instalado, imagens `1.1.0` baixadas antes, API e frontend recriados um de cada vez.
- `/api/info` responde `1.1.0`. O pedido criado no cenário 1 continua em **Meus pedidos**.

Alteração de infraestrutura que preserva os dados (ACE-05): repetir com
`db_instance_type=t3.small`. A VM do banco para e volta com o volume EBS, e o pedido continua lá.

## Cenário 3 — Reexecução sem alterações

**1. Deploy** com exatamente os mesmos parâmetros do cenário 2.

Mostrar:
- Terraform: `No changes. Your infrastructure matches the configuration.` e o passo de apply pulado.
- Ansible: `PLAY RECAP` com `changed=0` nas duas VMs.

## Validação da demanda

| Critério | Como demonstrar |
|---|---|
| ACE-01 Reprodução | cenário 1 + README (pré-requisitos e parâmetros) |
| ACE-02 Duas VMs | resumo "Infraestrutura" do deploy ou console EC2 com `*-app` e `*-db` + [inventario.md](inventario.md) |
| ACE-03 Isolamento | **2. Operações** › `isolation-check` (internet bloqueada, rede privada ok) + [acesso-administrativo.md](acesso-administrativo.md) |
| ACE-04 Aplicação | navegador: catálogo, pedido, recarregar, pedido continua |
| ACE-05 Persistência | `restart` com `service=all` + troca de `db_instance_type`; pedido continua |
| ACE-06 CI/CD | **0. App** publicando a tag → **1. Deploy** implantando a mesma tag ([integracao-cicd.md](integracao-cicd.md)) |
| ACE-07 Recuperação | execução automática das 03:00 (`logs` com `service=mongodb`) + `restore-verify` mostrando os pedidos restaurados |
| ACE-08 Administração | histórico dos workflows; logs sem senhas (`***`) |
| ACE-09 Custos | [custos.md](custos.md) |
| ACE-10 Transferência | [operacao.md](operacao.md) |

Encerrar com **3. Desativar** (`DESTRUIR dev`) para mostrar o encerramento e o resumo do
que continua existindo.
