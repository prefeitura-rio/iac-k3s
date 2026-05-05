# K3s on Incus Infrastructure

Infraestrutura como código para cluster K3s em contêineres Incus, utilizando Terraform, Ansible e Nix. Implanta Prefect, Airbyte, Infisical, Tailscale, SigNoz e CloudSQL Proxy.

## Estrutura

```
k3s/
├── terraform/       # Configurações Terraform
│   ├── deployments/ # Configurações específicas de aplicações
│   └── files/       # Arquivos gerados (kubeconfig, etc.)
├── scripts/         # Scripts de deployment
├── playbook.yaml    # Configuração Ansible
├── inventory.ini    # Inventário Ansible
└── justfile         # Automação de tarefas
```

## Documentação

Para informações detalhadas sobre arquitetura, padrões e práticas adotadas, consulte o [Guia de Integração (ONBOARD.md)](../ONBOARD.md) no repositório raiz.