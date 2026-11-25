# Procedimento administrativo de acesso (REQ-03 / REQ-04)

Este documento separa **como a aplicação acessa o banco** de **como um administrador acessa as
VMs e o MongoDB**.

## Caminhos de acesso

| Quem | Origem → destino | Porta | Como é permitido |
|---|---|---|---|
| Usuários da loja | internet → VM app | 80/443 | SG `app`, regras públicas |
| API (aplicação) | VM app → VM db `10.20.2.10` | 27017 | SG `db` aceita só o SG `app` (rede privada) |
| Pipeline (GitHub Actions) | runner → VM app | 22 | regra temporária para o IP do runner, removida no final |
| Pipeline (GitHub Actions) | runner → VM app → VM db | 22 | ProxyJump pela VM app; SG `db` aceita SSH só do SG `app` |
| Administrador (emergência) | console AWS → qualquer VM | nenhuma | AWS Systems Manager Session Manager |
| Administrador com IP fixo | IP em `ADMIN_CIDRS` → VM app (→ VM db) | 22 | regra do Terraform para o IP declarado |
| Qualquer um | internet → VM db | 27017 / 22 | **bloqueado** (sem regra de entrada pública) |

## 1. Acesso padrão: pela pipeline

Para o dia a dia não é preciso abrir terminal: status, logs, reinício, backup e restauração
ficam no workflow **2. Operações** ([operacao.md](operacao.md)). Cada execução fica registrada
no histórico do GitHub Actions (quem, quando, parâmetros, resultado).

## 2. Acesso emergencial sem portas: Session Manager

1. Console da AWS › **EC2 › Instâncias** › selecionar `vm-pm04-<amb>-db` (ou `-app`).
2. **Conectar › Session Manager › Conectar**.
3. Comandos úteis:
   ```bash
   sudo docker ps
   sudo docker logs --tail 100 mongodb
   sudo systemctl list-timers kubeshop-backup.timer
   ```

Funciona porque as VMs têm o perfil IAM com `AmazonSSMManagedInstanceCore`. Não exige chave SSH
nem regra de entrada.

## 3. SSH de um administrador

1. Cadastrar o IP público do administrador na variável `ADMIN_CIDRS` do repositório
   (ex.: `["200.1.2.3/32"]`) e rodar **1. Deploy**. O `plan` mostra só a regra nova.
2. Conectar com a chave correspondente ao secret `SSH_PRIVATE_KEY`:
   ```bash
   # VM da aplicação
   ssh -i ~/.ssh/kubeshop-pm04 ubuntu@<IP elástico>
   # VM do banco, passando pela VM da aplicação
   ssh -i ~/.ssh/kubeshop-pm04 -J ubuntu@<IP elástico> ubuntu@10.20.2.10
   ```
3. Ao terminar: remover o IP de `ADMIN_CIDRS` e rodar o deploy de novo.

## 4. Acesso administrativo ao MongoDB

A porta 27017 **nunca** é aberta para a internet. Duas opções:

- **Dentro da VM do banco** (Session Manager ou SSH):
  ```bash
  sudo docker exec -it mongodb mongosh -u admin --authenticationDatabase admin
  ```
  A senha (`MONGO_ROOT_PASSWORD`) é pedida no prompt e não fica no histórico.
- **Ferramenta gráfica (MongoDB Compass) por túnel SSH** pela VM da aplicação, que é a única
  autorizada a falar com o banco:
  ```bash
  ssh -i ~/.ssh/kubeshop-pm04 -N -L 27017:10.20.2.10:27017 ubuntu@<IP elástico>
  # Compass: mongodb://admin@localhost:27017/?authSource=admin
  ```

## Credenciais

| Credencial | Onde fica | Quem usa |
|---|---|---|
| Chave AWS da pipeline | GitHub Secrets `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | workflows |
| Chave SSH | GitHub Secret `SSH_PRIVATE_KEY` (+ cópia com o administrador) | pipeline e emergência |
| Senha root do MongoDB | GitHub Secret `MONGO_ROOT_PASSWORD`; na VM em arquivo `0400` | backup/restauração e administrador |
| Senha da aplicação no MongoDB | GitHub Secret `MONGO_APP_PASSWORD`; na VM em arquivo `0400` | API |
| Acesso da VM do banco ao S3 | perfil IAM da VM (sem chave gravada) | backup |

Nenhuma credencial fica no repositório. Nos logs aparecem como `***`, e as tarefas do Ansible
que manipulam senhas usam `no_log`.

**Troca da chave SSH:** as VMs só recebem a chave pública na criação. Para trocar sem recriar:
entrar por Session Manager, adicionar a nova chave pública em `/home/ubuntu/.ssh/authorized_keys`,
atualizar o secret `SSH_PRIVATE_KEY` e rodar o deploy (o key pair da AWS é atualizado sem
recriar as VMs).

**Auditoria:** histórico do GitHub Actions e o histórico de eventos do AWS CloudTrail (90 dias,
sem custo), que registra quem abriu e fechou as regras temporárias de SSH.
