# K3s on Incus Infrastructure

Infraestrutura como código para cluster K3s em contêineres Incus, utilizando Terraform, Ansible e Nix. Implanta Prefect, Airbyte, Infisical, Tailscale, SigNoz e CloudSQL Proxy.

## Estrutura

```
k3s/
├── live/k3s/        # Unidade Terragrunt: estado, provedores e variáveis SOPS
├── terraform/       # Módulo Terraform
│   └── deployments/ # Configurações específicas de aplicações
├── playbook.yaml    # Configuração Ansible
└── inventory.ini    # Inventário Ansible
```

## Uso

O shell Nix define `TG_WORKING_DIR` e `KUBE_HOST` (API do K3s via Tailscale). Conecte-se ao Tailscale e execute:

```
prefrio tf plan
prefrio tf apply
prefrio tf edit-vars
prefrio k get pods -A
```

## Documentação

Para informações detalhadas sobre arquitetura, padrões e práticas adotadas, consulte o [Guia de Integração (ONBOARD.md)](../ONBOARD.md) no repositório raiz.