# Relatório de validação e evidências

Salvar aqui os prints e logs usados no PDF de entrega. Para cada item, anotar o link da
execução do GitHub Actions (Actions > execução > copiar URL) e o resultado (OK/falha + observação).

| # | Evidência | Origem | Arquivo |
|---|---|---|---|
| 1 | Imagens 1.0.0 e 1.1.0 publicadas | 0. App (resumo) + página de pacotes do GHCR | |
| 2 | Cenário 1: plan com recursos a criar | 1. Deploy › terraform plan | |
| 3 | Cenário 1: Ansible instalando Docker e subindo contêineres | 1. Deploy › ansible-playbook | |
| 4 | Cenário 1: PLAY RECAP sem falhas + teste externo OK | 1. Deploy | |
| 5 | Loja no navegador (catálogo + pedido + recarregar) | navegador/celular | |
| 6 | Inventário: 2 VMs (`*-app`, `*-db`), IP elástico, volume | resumo "Infraestrutura" ou console EC2 | |
| 7 | Cenário 2: plan `updated in-place` (instance_type) | 1. Deploy › terraform plan | |
| 8 | Cenário 2: atualização do SO, pacote extra e imagem 1.1.0 | 1. Deploy › ansible-playbook | |
| 9 | Cenário 2: `/api/info` = 1.1.0 e pedido antigo preservado | teste externo + navegador | |
| 10 | Persistência após troca de `db_instance_type` | 1. Deploy + navegador | |
| 11 | Cenário 3: `No changes` + `changed=0` | 1. Deploy | |
| 12 | Isolamento do banco | 2. Operações › isolation-check | |
| 13 | Backup automatizado no S3 (execução das 03:00) | 2. Operações › logs (`service=mongodb`) + console S3 | |
| 14 | Restauração testada | 2. Operações › restore-verify | |
| 15 | Logs sem credenciais (`***`) | qualquer execução | |
| 16 | Desativação e o que continua existindo | 3. Desativar (resumo) | |
