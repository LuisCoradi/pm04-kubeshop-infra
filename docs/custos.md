# Estimativa de custos

## Premissas

| Item | Valor |
|---|---|
| Provedor / região | AWS, us-east-1 (Norte da Virgínia) |
| Moeda | dólar (US$), preços on-demand Linux, sem impostos |
| Data de referência | 23/11/2026 |
| Horas consideradas | 730 h/mês (ligado 24 h por dia) |
| Período do projeto | 14 dias (implantação, testes e apresentação) |
| Ambientes | 1 (dev). Cada ambiente adicional (homolog/prod) duplica o valor |

## Máquinas virtuais

| VM | Função | Tipo | vCPU | Memória | Motivo do dimensionamento |
|---|---|---|---|---|---|
| `*-app` | Caddy + frontend (Nginx) + API Node.js | t3.micro | 2 | 1 GiB | tráfego de demonstração; a API e o Nginx usam poucas dezenas de MB; 1 GB de swap para picos |
| `*-db` | MongoDB exclusivo | t3.micro | 2 | 1 GiB | cache do MongoDB limitado a 256 MB (mesmo valor do Compose validado); poucos pedidos fictícios |

Créditos de CPU em modo `standard`: as VMs não geram cobrança por uso de CPU acima da linha de
base. Se faltar folga, o parâmetro `instance_type`/`db_instance_type` sobe para t3.small
(2 vCPU, 2 GiB) sem recriar a VM.

## Composição mensal

| Recurso | Quantidade | Preço unitário | US$/mês |
|---|---|---|---|
| EC2 t3.micro (aplicação) | 730 h | US$ 0,0104/h | 7,59 |
| EC2 t3.micro (MongoDB) | 730 h | US$ 0,0104/h | 7,59 |
| EBS gp3: 2 discos de sistema de 12 GB + dados do MongoDB 10 GB | 34 GB | US$ 0,08/GB-mês | 2,72 |
| IPv4 público: IP elástico da loja + IP de saída da VM do banco | 2 × 730 h | US$ 0,005/h | 7,30 |
| S3: state + backups (14 cópias diárias de poucos MB) | < 1 GB | US$ 0,023/GB-mês | ~0,05 |
| Transferência de saída para a internet | < 100 GB | faixa gratuita de 100 GB/mês | 0,00 |
| **Total** | | | **≈ 25,25** |

Por dia: ≈ US$ 0,83. **Período do projeto (14 dias): ≈ US$ 12.**

## Armazenamento e backups

| Item | Capacidade | Cópias e retenção |
|---|---|---|
| Disco de sistema (cada VM) | 12 GB gp3 criptografado | removido junto com a VM |
| Dados do MongoDB | 10 GB gp3 criptografado | volume independente da VM; removido no destroy após o backup final |
| Backups lógicos (`mongodump` compactado) | poucos MB por cópia | 1 por dia no S3, retenção de 14 dias; 3 últimas cópias também na VM do banco |
| Terraform State | KB | versionado; versões antigas por 90 dias |

## Rede e serviços auxiliares

| Item | Custo | Observação |
|---|---|---|
| IPs públicos | incluído acima | 2 IPv4 (US$ 0,005/h cada) |
| NAT Gateway | não usado | evitaria o IP público do banco, mas custaria ≈ US$ 32,85/mês (US$ 0,045/h) |
| DNS | US$ 0 | Cloudflare (plano gratuito); só se `DOMAIN_NAME` for usado |
| Certificado TLS | US$ 0 | Let's Encrypt, emitido e renovado pelo Caddy |
| Domínio `trabaidafacul.site` | já pago | renovação anual no registrador; fora do custo mensal da AWS |
| Logs | US$ 0 | Docker com rotação local (3 × 10 MB por contêiner) e histórico do GitHub Actions; sem CloudWatch Logs |
| Execução dos pipelines | US$ 0 | GitHub Actions gratuito em repositório público (privado: 2.000 min/mês no plano Free) |
| Registry de imagens | US$ 0 | GHCR gratuito para pacotes públicos |

## Limitações e fatores que alteram o valor

- Preços públicos da AWS na data de referência, sem impostos brasileiros (a AWS Brasil emite nota com tributos).
- Considera as VMs ligadas 24 h. Desligar o ambiente com **3. Desativar** zera EC2, EBS e IPs.
- t3.small na aplicação (cenário 2): +US$ 7,59/mês (US$ 0,0208/h).
- Cada ambiente extra (homolog/prod) soma ≈ US$ 25/mês.
- Tráfego acima de 100 GB/mês de saída passa a ser cobrado.
- Em sa-east-1 (São Paulo) a t3.micro custa ≈ US$ 0,0168/h: o total subiria para ≈ US$ 35/mês, com menor latência para clientes no Brasil.

## Créditos e faixa gratuita (separados do custo recorrente)

Contas AWS novas (criadas a partir de 15/07/2025) recebem US$ 100 em créditos na criação e
podem ganhar mais US$ 100 em atividades, válidos por até 6 meses no plano gratuito. Esses
créditos cobrem o período do projeto, mas **não mudam o custo recorrente acima**: depois que
acabarem, o ambiente custa ≈ US$ 25/mês enquanto estiver ligado.

## O que continua cobrando após a desativação

Só o bucket S3 (state versionado + backups até expirarem): centavos por mês.

## Fontes

- Preços EC2 T3 (us-east-1): https://aws.amazon.com/ec2/instance-types/t3/
- Cobrança de IPv4 público (US$ 0,005/h desde 01/02/2024): https://aws.amazon.com/blogs/aws/new-aws-public-ipv4-address-charge-public-ip-insights/
- Preços EBS: https://aws.amazon.com/ebs/pricing/
- Preços S3: https://aws.amazon.com/s3/pricing/
- Preços VPC / NAT Gateway: https://aws.amazon.com/vpc/pricing/
- Plano gratuito da AWS: https://aws.amazon.com/free/
