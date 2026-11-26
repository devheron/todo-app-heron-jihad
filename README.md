# PM-04 — ToDo App na Azure com Terraform + Ansible

Projeto final da disciplina Infraestrutura por Meio de Código (IaC) e Engenharia de Confiabilidade de Sites (SRE) da UniAmérica. Automação ponta a ponta do ToDo App (escopo 2 do professor) na Microsoft Azure, com pipeline de CI/CD acionando Terraform (provisionamento), Ansible (configuração) e publicação via HTTPS.

## Integrantes

- Heron Felipe — [@devheron](https://github.com/devheron)
- Jihad — [@Jihas2](https://github.com/Jihas2)

## Demanda

O ToDo App é uma aplicação React + Node.js/Express + MongoDB que precisa ir pra nuvem com a aplicação em uma VM e o banco em outra, comunicação pela rede privada, dados persistentes e automação de infraestrutura por pipeline. O escopo exige publicação por URL HTTPS. Escopo original em `escopo.pdf`.

## Arquitetura

```
                        Internet
                           │
                HTTPS 443 / HTTP 80 (redireciona)
                           ▼
              ┌────────────────────────┐
              │  Azure Load Balancer   │  IP público único
              │  443 e 80 → VM app     │
              │  2222 → SSH app        │
              │  2223 → SSH db         │
              └────────────┬───────────┘
                           │
          ┌────────────────┴─────────────────┐
          │       VNet 10.0.0.0/16           │
          │                                  │
          │  ┌──────────────────────────┐    │
          │  │ snet-app  10.0.1.0/24    │    │
          │  │ vm-pm04 (sem IP público) │    │
          │  │ ┌────────┐ ┌──────────┐  │    │
          │  │ │ Caddy  │→│  Nginx   │  │    │
          │  │ │ TLS    │ │  React   │  │    │
          │  │ │ 80/443 │ │  :80     │  │    │
          │  │ └────────┘ └────┬─────┘  │    │
          │  │                 │        │    │
          │  │             ┌───▼──────┐ │    │
          │  │             │ API Node │ │    │
          │  │             │ :5000    │ │    │
          │  │             └────┬─────┘ │    │
          │  └──────────────────┼───────┘    │
          │                     │ 27017      │
          │  ┌──────────────────▼───────┐    │
          │  │ snet-db   10.0.2.0/24    │    │
          │  │ vm-pm04-db (sem IP púb.) │    │
          │  │ ┌─────────────────────┐  │    │
          │  │ │ MongoDB :27017      │  │    │
          │  │ │ volume persistente  │  │    │
          │  │ └─────────────────────┘  │    │
          │  └──────────────────────────┘    │
          └──────────────────────────────────┘
```

## Pré-requisitos

- Conta Azure com Service Principal (role Contributor)
- Storage Account no `rg-pm04` com container `tfstate` (guarda o state do Terraform)
- Terraform 1.9+ e Ansible 10+ (só pra rodar local, a pipeline já instala)

## Secrets do repositório

Configurados em Settings → Secrets and variables → Actions:

| Nome | Para que serve |
|---|---|
| `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID` | autenticação do Terraform no Azure |
| `SSH_PUBLIC_KEY`, `SSH_PRIVATE_KEY` | chave ed25519 usada nas VMs |
| `MONGO_ROOT_PASSWORD`, `MONGO_APP_PASSWORD` | credenciais do MongoDB |

Nenhuma credencial fica no código. O login no GHCR é pelo `GITHUB_TOKEN` da própria pipeline.

## Como executar a pipeline

1. GitHub → aba **Actions** → **Deploy PM-04 ToDo App** → **Run workflow**.
2. Preencher os parâmetros (ou aceitar o default).

| Parâmetro | Default | Função |
|---|---|---|
| `acao` | deploy | `deploy` cria ou atualiza; `destroy` apaga tudo |
| `environment` | dev | Ambiente (dev/homolog/prod); define o nome do RG e o state |
| `instance_name` | vm-pm04 | Nome da VM da app; a do banco recebe `-db` |
| `instance_type` | Standard_D2als_v6 | Tamanho da VM |
| `docker_image` | ghcr.io/devheron/todo-app-heron-jihad | Prefixo das imagens |
| `docker_tag` | v1 | Versão fixa das imagens (não usar `latest`) |
| `build_images` | true | Buildar e publicar imagens antes do deploy |
| `update_os` | false | Rodar `apt upgrade` nas VMs |
| `extra_packages` | curl,git,unzip | Pacotes extras instalados pelo Ansible |

3. **Primeira execução apenas**: depois do job `build`, tornar os pacotes `-backend` e `-frontend` públicos em `github.com/devheron?tab=packages` → Package settings → Change visibility → Public. Sem isso o Ansible não consegue puxar as imagens do GHCR.
4. A URL HTTPS aparece no Summary do run quando termina.

## Estrutura

```
todo-app-heron-jihad/
├── .github/workflows/
│   └── deploy.yml              # pipeline (build + terraform + ansible)
├── terraform/
│   ├── providers.tf            # azurerm ~> 4.0
│   ├── backend.tf              # state remoto no Storage Account
│   ├── variables.tf            # inputs da pipeline
│   ├── main.tf                 # RG, VNet, subnets, NSGs, VMs, LB, NAT rules
│   └── outputs.tf              # IPs, URL HTTPS e inventory do Ansible
├── ansible/
│   ├── ansible.cfg
│   ├── playbook.yml            # play do banco + play da aplicação
│   ├── group_vars/             # variáveis gerais, da VM app e da VM banco
│   └── roles/
│       ├── os_updates/         # apt upgrade condicional + pacotes
│       ├── docker/             # Docker + Compose plugin pelo repo oficial
│       └── containers/         # MongoDB, API, Nginx/React e Caddy
├── backend/                    # API Node/Express (lê MONGO_URI do ambiente)
├── frontend/                   # React
├── banco-de-dados/             # Dockerfile base do Mongo
├── evidencias/                 # prints dos cenários e validação da demanda
└── escopo.pdf                  # demanda original
```

## HTTPS automático (REQ-05)

O escopo exige publicação por HTTPS. Para atender sem registrar domínio nem pagar por certificado, a solução usa três componentes abertos:

**nip.io — DNS por IP embutido.** O serviço público nip.io responde qualquer consulta DNS do tipo `<ip>.nip.io` devolvendo o próprio IP. Exemplo: `20.230.78.168.nip.io` resolve para `20.230.78.168`. É gratuito, não exige cadastro e está no ar há mais de dez anos. Permite ter um nome de domínio público apontando pro Load Balancer sem comprar ou configurar nada.

**Caddy — servidor web com TLS automático.** Caddy é um servidor HTTP escrito em Go que implementa o cliente ACME do Let's Encrypt nativamente. Ao subir, ele lê o Caddyfile, identifica os domínios configurados, pede o certificado no Let's Encrypt usando o desafio HTTP-01 (o Let's Encrypt faz uma requisição na porta 80 pra validar que quem pede o cert controla o IP), instala o certificado e passa a servir HTTPS. Renova sozinho antes de vencer. No projeto, o Caddy fica na frente do container do frontend fazendo reverse proxy pra `todo-frontend:80` pela rede Docker interna.

**Let's Encrypt — autoridade certificadora gratuita.** Emite certificados TLS reais, aceitos por todos os navegadores. A mesma AC usada por milhões de sites em produção. Os certs emitidos pra nip.io são certs normais X.509 com validade de 90 dias, renovados pelo Caddy automaticamente.

**Fluxo da primeira requisição:**
1. Terraform provisiona o LB com IP público (ex: `20.230.78.168`) e abre as portas 80 e 443.
2. Ansible sobe o container Caddy na VM da app com o domínio `20.230.78.168.nip.io` configurado.
3. Caddy abre a porta 80 pro desafio ACME. Let's Encrypt faz `GET http://20.230.78.168.nip.io/.well-known/acme-challenge/<token>`, cai no LB, chega no Caddy, retorna o token esperado.
4. Let's Encrypt valida e emite o cert. Caddy salva em `/data/caddy/certificates/` dentro do volume Docker `todo-caddy-data`.
5. A partir daí, qualquer acesso em `https://20.230.78.168.nip.io/` é servido pelo Caddy com cert válido. HTTP é redirecionado 308 para HTTPS.

**Reexecução e renovação.** Como o cert fica num volume Docker persistente, reexecuções da pipeline reusam o cert existente até faltar 30 dias pro vencimento, quando o Caddy renova silenciosamente. Isso evita bater no rate limit do Let's Encrypt (50 certs por semana pra nip.io) nos cenários 2 e 3 e em deploys frequentes.

## Decisões técnicas

- **Azure.** Era o provedor sugerido na aula e o professor demonstrou em classe o padrão de LB + VNet + VMs + NAT rules, que foi reproduzido aqui.
- **State remoto separado da infra.** O `tfstate` fica no `rg-pm04`, mas a infra vai pro `rg-pm04-<environment>`. Assim o Terraform nunca mexe no RG que guarda o próprio state.
- **Um state por ambiente.** A pipeline passa `-backend-config="key=pm04-<env>.tfstate"`, então trocar `environment` de dev pra prod não destrói o dev.
- **NSG no banco, dupla camada.** Em vez de confiar só na ausência de IP público, coloquei uma regra Allow explícita pra 27017 vindo de `snet-app` e uma regra Deny pra 27017 de qualquer outra origem.
- **IP público só no LB.** As VMs não têm IP público. SSH entra pela 2222 (app) e 2223 (db) do LB. Mesmo desenho do professor.
- **NAT rule no HTTP/HTTPS em vez de `lb_rule`.** O backend pool tem as duas VMs (precisa das duas pra ter outbound), então uma `lb_rule` mandaria tráfego pro banco também. NAT rule deixa 80 e 443 só na VM da app.
- **Inventory do Ansible via output do Terraform.** Se fosse `local_file`, cada runner novo recriaria o arquivo e o Cenário 3 mostraria "1 to add" em vez de "No changes". A pipeline grava o `hosts.yml` a partir do output `ansible_inventory`.
- **Imagens com tag fixa.** `docker_tag` default `v1`, nunca `latest`. O escopo pede atualização controlada e versão rastreável.
- **Senha do Mongo com `urlencode`.** Caracteres como `/` e `@` na senha quebram a MONGO_URI. O Ansible aplica `urlencode` + `replace('/', '%2F')` antes de montar a URI.

## Cenários testados

- **Cenário 1 — Criação inicial.** Terraform `Plan: 24 to add`, Ansible instalando Docker, MongoDB, API, frontend e Caddy. App no ar com HTTPS em menos de 7 minutos.
- **Cenário 2 — Atualização.** Troca de `instance_type` + novo `extra_packages`. Terraform mostra `1 to change` (resize in-place da VM, sem destruir), Ansible instala o pacote novo. Dados preservados.
- **Cenário 3 — Reexecução sem alterações.** Mesmos parâmetros do Cenário 2. Terraform "No changes" e Ansible com `changed=0` em todos os hosts (idempotência).

Prints de cada cenário em `evidencias/`.

## Operação

- **Acessar o app:** URL HTTPS no Summary da última execução.
- **SSH na VM da app:** `ssh -i ~/.ssh/pm04 -p 2222 azureuser@<IP_DO_LB>`
- **SSH na VM do banco:** `ssh -i ~/.ssh/pm04 -p 2223 azureuser@<IP_DO_LB>`
- **Logs da API:** `docker logs todo-backend` (dentro da VM da app)
- **Logs do Caddy (debug de cert):** `docker logs todo-caddy` (dentro da VM da app)
- **Logs do Mongo:** `docker logs todo-mongodb` (dentro da VM do banco)
- **Apagar o ambiente:** Run workflow com `acao=destroy`. Apaga o `rg-pm04-<env>` inteiro e para a cobrança na Azure.

## Validação da demanda

Comparação requisito por requisito do `escopo.pdf` com o que foi entregue está em `evidencias/validacao-demanda.md`.
