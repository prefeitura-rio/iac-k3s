# Infrastructure as Code - K3s on Incus

K3s cluster infrastructure using Terraform, Incus containers, and Ansible. Deploys Prefect, Airbyte, Infisical, and Tailscale on containerized Kubernetes.

## Structure

- `/`: Ansible configuration (`playbook.yaml`, `inventory.ini`)
- `terraform/`: Infrastructure and application deployments
- `flake.nix`: Nix development environment

## Getting Started

### Prerequisites

- [Nix](https://nixos.org/download.html) (recommended) or: Terraform, Ansible, Incus, Google Cloud SDK, Infisical, just
- SSH access to Incus host
- Google Cloud Storage bucket for Terraform state
- Infisical project for secret management

### Setup

```sh
nix develop  # or: direnv allow
```

All Terraform commands use `infisical run` for secret injection.

### Deployment

#### 1. Configure Host

```sh
just ping    # test connectivity
just deploy  # install Incus, configure permissions
```

#### 2. Deploy Cluster

```sh
cd terraform
just auth && just init && just plan && just apply
```

#### 3. Access Cluster

```sh
cd terraform
just k3s-forward  # forward K3s API through SSH
export KUBECONFIG=./files/kubeconfig
kubectl get nodes
```

## Commands

### Host Management

```sh
just ping       # test connectivity
just deploy     # configure Incus host
```

### Infrastructure (in terraform/)

```sh
just auth           # authenticate services
just init           # initialize Terraform
just plan           # plan changes
just apply          # deploy infrastructure
just k3s-forward    # forward K3s API (6443)
just incus-forward  # forward Incus API (8443)
just stop-forward   # stop port forwarding
just destroy        # destroy infrastructure
```

## Configuration

Variables in `terraform/variables.tf` (defaults: 3 workers, 2 CPU, 6GB RAM, 30GB disk per container).

Sensitive variables stored in Infisical: `incus`, `prefect_address`, `github`, `tailscale`, `infisical`.

## Applications

- **Prefect**: Workflow orchestration
- **Airbyte**: Data integration
- **Infisical**: Secret management
- **Tailscale**: Secure networking with MagicDNS
