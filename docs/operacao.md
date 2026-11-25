# Manual de operação

Todas as rotinas rodam em **GitHub > Actions**, escolhendo o workflow e clicando em
**Run workflow**. Ninguém precisa entrar nos servidores. Cada execução fica registrada com
log, autor e horário; credenciais aparecem como `***`.

## Rotinas do dia a dia

| Rotina | Workflow e parâmetros | Resultado esperado | Se falhar |
|---|---|---|---|
| Publicar nova versão das imagens | **0. App** · `version=1.1.0` | imagens `-api` e `-frontend` com a tag no GHCR | ver o passo de testes; o build não publica se os testes falharem |
| Criar ou atualizar o ambiente | **1. Deploy** · parâmetros da execução | plan → apply → Ansible com `failed=0` → "Loja disponível" com o endereço | a pipeline para no passo que falhou; corrigir e rodar de novo (é idempotente) |
| Ver o que mudaria, sem aplicar | **1. Deploy** · `plan_only=true` | resumo do `terraform plan` | erro de validação aparece no `terraform validate` |
| Saúde e versões | **2. Operações** · `status` | contêineres `healthy`, versão em `/api/info`, disco, memória, próximo backup | rodar `logs` |
| Logs | **2. Operações** · `logs` · `service` | últimas 100 linhas de cada contêiner e execuções do backup | — |
| Reiniciar serviços | **2. Operações** · `restart` · `service` | contêiner reiniciado e `healthy` (dados preservados) | rodar `logs` do serviço |
| Teste funcional | **2. Operações** · `smoke` | `"result":"PASS"`; cria **um** pedido fictício | rodar `logs` da `api` |
| Teste de isolamento do banco | **2. Operações** · `isolation-check` | 27017 bloqueada pela internet; acessível da VM app pela rede privada | revisar security groups no `terraform plan` |
| Backup agora | **2. Operações** · `backup` | JSON com arquivo, tamanho, nº de pedidos e destino no S3 | rodar `logs` com `service=mongodb` |

O backup também roda sozinho todo dia às 03:00 (horário de Brasília). Os arquivos ficam em
`s3://kubeshop-<conta>-<região>/backups/<ambiente>/` por 14 dias e as 3 últimas cópias também
ficam na VM do banco.

## Ações que alteram ou removem dados

Ficam separadas das rotinas comuns e exigem confirmação digitada.

| Ação | Workflow e parâmetros | O que acontece |
|---|---|---|
| Testar restauração | **2. Operações** · `restore-verify` · `backup_ref=latest` | baixa o backup, restaura num MongoDB temporário **sem rede**, mostra quantos pedidos e o último pedido; o banco em uso não é tocado |
| Restaurar dados | **2. Operações** · `restore-replace` · `backup_ref` · `confirm=RESTAURAR <amb>` | backup de segurança do estado atual e depois substitui o banco `kubeshop` pelo backup escolhido |
| Desativar o ambiente | **3. Desativar** · `confirm=DESTRUIR <amb>` | backup final → `terraform destroy` → lista do que continua existindo |

`backup_ref` aceita `latest` ou o nome do arquivo (ex.: `kubeshop-dev-20261125T030512Z.archive.gz`),
que aparece no resultado da rotina `backup` e no S3.

## Destino dos dados ao desativar

| Item | Depois do destroy |
|---|---|
| VMs, IP elástico, VPC, security groups, perfis IAM | removidos (param de cobrar) |
| Volume EBS com os dados do MongoDB | removido; os dados ficam no **backup final** no S3 |
| Bucket S3 (state + backups) | continua; backups expiram em 14 dias; custo de centavos |
| Imagens no GHCR | continuam (fora da AWS) |
| Domínio | continua (renovação anual no registrador) |

Para recriar: **1. Deploy**. Para trazer os dados de volta: **2. Operações** › `restore-replace`.

## Falhas comuns

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| `terraform init` falha com AccessDenied | secrets da AWS ausentes ou sem permissão | conferir `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` e as políticas do usuário IAM |
| `Unsupported instance type` / erro de plano gratuito | tipo fora do plano gratuito | usar t3.micro ou t3.small |
| "SSH não respondeu em 5 minutos" | VM ainda iniciando ou chave errada | rodar de novo; conferir `SSH_PRIVATE_KEY` |
| Erro ao baixar imagem (`denied`/`unauthorized`) | pacote do GHCR sem acesso pelo repositório | tornar o pacote público ou criar o secret `GHCR_TOKEN` (`read:packages`) |
| "A versão X não ficou saudável. Aplicação revertida para Y." | nova imagem não sobe ou não alcança o banco | a loja continua na versão anterior; ver `logs` da `api` |
| `/api/health/ready` responde 503 | MongoDB parado ou inacessível | `status`; `restart` com `service=mongodb`; `isolation-check` |
| Teste externo falha com domínio | DNS ainda não aponta para o IP elástico | criar o registro A (sem proxy da Cloudflare) e rodar o deploy de novo |
| "Contêiner ... não está rodando/saudável" | serviço caiu após configuração | `logs` do serviço, depois `restart` |

## Terraform State: armazenamento, proteção e recuperação

| Aspecto | Como está |
|---|---|
| Armazenamento | `s3://kubeshop-<conta>-<região>/tfstate/<amb>/terraform.tfstate`, um arquivo por ambiente |
| Proteção | bucket privado (bloqueio de acesso público), criptografia AES-256, acesso só pela credencial da pipeline |
| Concorrência | trava nativa do S3 (`terraform.tfstate.tflock`) + execução serializada por ambiente no GitHub Actions |
| Histórico | versionamento do bucket; versões antigas guardadas por 90 dias |

**Voltar para uma versão anterior do state** (ex.: arquivo corrompido), com AWS CLI ou CloudShell:

```bash
B=kubeshop-<conta>-<região>; K=tfstate/dev/terraform.tfstate
aws s3api list-object-versions --bucket "$B" --prefix "$K" \
  --query 'Versions[].[VersionId,LastModified,Size]' --output table
aws s3api copy-object --bucket "$B" --key "$K" --copy-source "$B/$K?versionId=<VersionId>"
```

Depois, rodar **1. Deploy** com `plan_only=true` e conferir se o plano faz sentido.

**Trava presa** (execução cancelada no meio do apply): o erro mostra o `ID` da trava. Confirmar
que nenhuma execução está rodando e apagar o arquivo da trava:
`aws s3 rm s3://$B/tfstate/dev/terraform.tfstate.tflock`.

**State perdido por completo** (último recurso): os recursos continuam na AWS com as tags do
ambiente. Reimportar com `terraform import` (ex.: `terraform import aws_instance.app i-0123...`)
ou destruí-los pelo console filtrando a tag `Environment` e recriar pelo **1. Deploy**,
restaurando os dados do backup.

## Acesso de emergência

Procedimento completo, separado do acesso da aplicação ao banco:
[acesso-administrativo.md](acesso-administrativo.md). Resumo: Session Manager pelo console da
AWS (sem porta aberta) ou SSH com o IP do administrador em `ADMIN_CIDRS`.
