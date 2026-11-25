# Integração com o CI/CD da aplicação (escopo item 7 / ACE-06)

## Responsabilidades

| Fluxo | Dono | Faz | Não faz |
|---|---|---|---|
| CI/CD da aplicação | Zibiska Korp (existente) | testa o código, gera e publica as imagens com uma tag de versão | não acessa a AWS nem os servidores |
| Pipelines de infraestrutura | este repositório | cria, configura, atualiza, mantém, faz backup/restauração e desativa o ambiente; implanta a tag pedida | não altera o código da aplicação |

O ponto de integração é o **registry de imagens**: a aplicação publica, a infraestrutura
implanta a tag informada.

```
código KubeShop ──> [CI/CD da aplicação] ──push──> ghcr.io/<dono>/kubeshop-api:<versão>
                                                     ghcr.io/<dono>/kubeshop-frontend:<versão>
                                                               │
                               [1. Deploy] docker_tag=<versão> ─┘──pull──> VM app
```

O repositório do KubeShop não traz pipeline. Para a demonstração, o workflow
**0. App** (`app-images.yml`) faz o papel do CI/CD existente: baixa o código de
`LaercioMLB/kube-shop-v2` num commit fixo, roda os testes (`npm test`) e publica as duas imagens.
Se a Zibiska Korp usar outro sistema de CI, basta que ele publique no mesmo destino e com o
mesmo padrão de nomes.

## Contrato entre os pipelines

| Item | Valor |
|---|---|
| Registry | GitHub Container Registry (`ghcr.io`) |
| Imagens | `<prefixo>-api` e `<prefixo>-frontend`; prefixo padrão `ghcr.io/<dono-do-repo>/kubeshop` |
| Dockerfiles | `apps/backend/Dockerfile` e `apps/frontend/Dockerfile`, contexto na raiz do repositório |
| Tags | versão fixa (`1.0.0`, `1.1.0`) + `sha-<commit>` para rastreio. Evitar `latest` |
| Metadados | labels OCI `source`, `version`, `revision` (commit do código) |
| Implantação | workflow **1. Deploy** com `docker_tag=<versão>` (e `docker_image` se o prefixo for outro) |
| Variáveis da API definidas pela infraestrutura | `MONGO_HOST`, `MONGO_PORT`, `MONGO_DATABASE`, `MONGO_USERNAME`, `MONGO_PASSWORD_FILE`, `APP_VERSION` (= `docker_tag`) |
| Verificação após implantar | `/api/health/ready` = 200 e `/api/info` com a versão pedida; se falhar, volta para a versão anterior |

## Parâmetros do 0. App

| Parâmetro | Exemplo | Função |
|---|---|---|
| `version` | 1.1.0 | tag publicada |
| `source_ref` | commit ou branch | versão do código a construir (padrão: commit validado `ee30950`) |
| `run_tests` | true | roda os testes antes do build |

## Credenciais (referências, sem valores)

| Onde | Credencial | Permissão |
|---|---|---|
| 0. App (publicar) | `GITHUB_TOKEN` automático | `packages: write` |
| 1. Deploy (baixar nas VMs) | `GITHUB_TOKEN` automático, ou o secret `GHCR_TOKEN` se configurado | `packages: read`; login temporário na VM, com logout no final |
| CI externo da Zibiska (se usado) | token próprio com `write:packages` | guardado no CI deles |

## Disparar a implantação a partir do CI da aplicação (opcional)

Depois de publicar a versão, o CI da aplicação pode chamar o deploy:

```bash
gh workflow run deploy.yml --repo <dono>/<repo-infra> \
  -f environment=homolog -f docker_tag=1.1.0
```

Os demais parâmetros usam os valores padrão do workflow. Em produção, a recomendação é manter o
deploy manual e protegido por aprovação no ambiente `prod` (GitHub › Settings › Environments ›
Required reviewers).
