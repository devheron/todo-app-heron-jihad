# Validação da demanda — ToDo App PM-04

Comparação entre os requisitos do `escopo.pdf` (seção 4, Requisitos da solução) e a infraestrutura entregue.

| Requisito | O que o escopo pede | Como foi atendido | Status |
|---|---|---|---|
| **REQ-01 — Servidores** | Mínimo 2 VMs, uma dedicada ao MongoDB | `vm-pm04` (Nginx + React + API Node) na subnet `snet-app`; `vm-pm04-db` (MongoDB) na subnet `snet-db`. Cada VM com NIC, NSG e tamanho próprios, provisionadas pelo Terraform. | ✅ |
| **REQ-02 — Rede privada** | MongoDB acessível só pela VM da aplicação, sem porta pública | NSG `nsg-db`: regra `mongodb-da-app` libera 27017 só da origem `10.0.1.0/24`; regra `mongodb-bloqueado` nega 27017 de qualquer outra origem. O container do MongoDB publica a porta apenas no IP privado da VM (nunca em `0.0.0.0`). | ✅ |
| **REQ-03 — Acessos** | Credenciais e segredos fora do código e dos logs | 8 secrets no GitHub Actions (ARM_\*, SSH_\*, MONGO_\*). Service Principal com role mínima Contributor. Ansible usa `no_log: true` nas tasks de login no registry, criação dos containers com senha e autenticação no Mongo. Arquivos `.tfstate`, `.tfvars` e `hosts.yml` gerado ficam no `.gitignore`. | ✅ |
| **REQ-04 — Persistência** | Tarefas preservadas após reinício; alteração de infraestrutura sem perder dados | Container do MongoDB com volume Docker nomeado `todo-mongo-data` em `/data/db`. VM do banco é recurso separado no Terraform, então mudanças em `instance_type` ou `docker_tag` da aplicação não tocam na VM do banco nem no volume. Testado no Cenário 2 (resize da VM da app com dados mantidos). | ✅ |
| **REQ-05 — Publicação** | URL única HTTPS com frontend e API no mesmo endereço | Load Balancer Standard expõe portas 80 e 443 pro IP público. Container Caddy na VM da app recebe o tráfego HTTPS, obtém e renova o certificado TLS automaticamente no Let's Encrypt usando o domínio público `<IP_DO_LB>.nip.io`, e faz reverse proxy pro container do frontend pela rede Docker interna. Porta 80 responde 308 redirecionando pra 443. Certificado fica em volume persistente (`todo-caddy-data`), evitando pedido novo em cada execução da pipeline. | ✅ |
| **REQ-06 — Disponibilidade** | Reinício de serviços, checagem de saúde, diagnóstico de falhas | Todos os containers com `restart_policy: always`. Ansible valida em cada execução: redirecionamento HTTP → HTTPS, resposta 200 em `https://<domínio>/` e em `https://<domínio>/todos` (confirma frontend, API e banco). `wait_for` no MongoDB antes de seguir. Logs acessíveis por `docker logs` nas duas VMs via SSH pelas portas 2222 e 2223 do LB. | ✅ |

## Notas

- O item HTTPS foi resolvido sem compra de domínio nem configuração manual de certificado, usando a combinação **nip.io + Caddy + Let's Encrypt**. Detalhes do funcionamento estão no README.
- Os três cenários previstos no enunciado (seção 5, Testes obrigatórios) foram executados pela pipeline. Prints em `evidencias/cenario1/`, `evidencias/cenario2/` e `evidencias/cenario3/`.
