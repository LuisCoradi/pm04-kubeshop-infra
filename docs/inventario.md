# Inventário dos recursos

Por ambiente (`<amb>` = dev, homolog ou prod). Todos têm as tags `Project=kubeshop`,
`Client=zibiska-korp`, `Environment=<amb>` e `ManagedBy=terraform`. Para listar no console:
**Resource Groups › Tag Editor › tag Environment = <amb>**.

## Na AWS (Terraform)

| Recurso Terraform | Nome na AWS | Função |
|---|---|---|
| `aws_vpc.main` | `kubeshop-<amb>-vpc` | rede privada 10.20.0.0/16 |
| `aws_internet_gateway.main` | `kubeshop-<amb>-igw` | saída para a internet |
| `aws_subnet.app` | `kubeshop-<amb>-app` | sub-rede 10.20.1.0/24 da aplicação |
| `aws_subnet.db` | `kubeshop-<amb>-db` | sub-rede 10.20.2.0/24 do banco |
| `aws_route_table.public` (+ 2 associações) | `kubeshop-<amb>-rt` | rota padrão pelo internet gateway |
| `aws_security_group.app` + regras | `kubeshop-<amb>-app` | 80/443 públicos; 22 só IPs autorizados |
| `aws_security_group.db` + regras | `kubeshop-<amb>-db` | 27017 e 22 só a partir do SG app |
| `aws_key_pair.admin` | `kubeshop-<amb>` | chave pública SSH de administração |
| `aws_iam_role.app` / `aws_iam_instance_profile.app` | `kubeshop-<amb>-app` | Session Manager |
| `aws_iam_role.db` / `aws_iam_instance_profile.db` + `aws_iam_role_policy.db_backups` | `kubeshop-<amb>-db` | Session Manager + gravar/ler backups no S3 |
| `aws_instance.app` | `<instance_name>-<amb>-app` | VM 1: Caddy, frontend, API |
| `aws_eip.app` | `kubeshop-<amb>-app` | IP público fixo da loja |
| `aws_instance.db` | `<instance_name>-<amb>-db` | VM 2: MongoDB exclusivo, IP 10.20.2.10 |
| `aws_ebs_volume.mongo_data` + `aws_volume_attachment` | `kubeshop-<amb>-mongo-data` | 10 GB com os dados do MongoDB |

## Na conta (fora do Terraform, um por conta/região)

| Recurso | Nome | Criado por | Função |
|---|---|---|---|
| Bucket S3 | `kubeshop-<conta>-<região>` | `scripts/bootstrap-backend.sh` (pipeline) | `tfstate/<amb>/` (state) e `backups/<amb>/` (backups) |
| Usuário IAM | ex.: `github-pm04` | equipe, uma vez | credencial da pipeline |

## Dentro das VMs (Ansible)

| VM | Componente | Detalhe |
|---|---|---|
| app | contêiner `caddy` | `caddy:2.11.9-alpine`, portas 80/443 |
| app | contêiner `frontend` | `<prefixo>-frontend:<tag>`, rede `kubeshop`, 8080 interna |
| app | contêiner `api` | `<prefixo>-api:<tag>`, rede `kubeshop`, 3000 interna |
| db | contêiner `mongodb` | `mongo:8.0.17`, `10.20.2.10:27017`, dados em `/srv/kubeshop-data/mongo` |
| db | `kubeshop-backup.timer` | backup diário 03:00 → S3; cópias locais em `/var/backups/kubeshop` |
| db | `/usr/local/bin/kubeshop-backup` e `kubeshop-restore` | rotinas usadas pela pipeline |
| ambas | Docker Engine, swap de 1 GB, pacotes base + `extra_packages` | configurados pelo Ansible |
| ambas | `/opt/kubeshop/` | configurações e segredos (arquivos `0400`) |

Os valores reais (IPs, IDs) aparecem no resumo **Infraestrutura** de cada execução do
**1. Deploy** (outputs do Terraform).
