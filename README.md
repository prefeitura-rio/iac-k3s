# Infrastructure as Code - K3s on Incus

K3s cluster infrastructure using Terraform, Incus containers, and Ansible. Deploys Prefect, Airbyte, Infisical, Tailscale, SigNoz, and CloudSQL Proxy on containerized Kubernetes.

## Structure

- `/`: Ansible configuration (`playbook.yaml`, `inventory.ini`)
- `terraform/`: Infrastructure and application deployments
  - `deployments/`: Application-specific Terraform configurations
  - `files/`: Generated files (kubeconfig, etc.)
  - `scripts/`: Deployment scripts
- `flake.nix`: Nix development environment

## Getting Started

### Prerequisites

- [Nix](https://nixos.org/download.html) (recommended) or: Terraform, Ansible, Incus, Google Cloud SDK, Infisical, just
- SSH access to target host
- Google Cloud Storage bucket for Terraform state
- Infisical project for secret management

### Setup

```sh
nix develop  # or: direnv allow
```

The project uses Nix flakes for reproducible development environments. The `.envrc` file automatically configures environment variables and enables the development shell when using direnv.

All Terraform commands use `infisical run` for secret injection.

**Required Environment Variables:**

**Automatically Set Environment Variables (via .envrc):**

- `ANSIBLE_BECOME_PASSWORD_FILE`: Points to `./.password` for Ansible privilege escalation
- `ANSIBLE_INVENTORY`: Points to `./inventory.ini`
- `KUBECONFIG`: Points to `./terraform/files/kubeconfig`
- `INCUS_TOKEN_FILE`: Points to `./incus-token.txt`
- `INCUS_SERVER_HOST`: Set to `k3s` (Tailscale hostname)
- `INCUS_SERVER_USER`: Set to `k3s`
- `K3S_MASTER_HOSTNAME`: Set to `k3s-master`
- `TF_VAR_cluster_name`: Set to `k3s`

### Deployment

#### 1. Configure Host

```sh
just ansible    # configure Incus host via Ansible
```

#### 2. Deploy Cluster

```sh
just auth && just init && just plan && just apply
```

#### 3. Access Cluster

```sh
export KUBECONFIG=./terraform/files/kubeconfig
kubectl get nodes
```

## Just Commands Reference

This project uses [just](https://github.com/casey/just) as a command runner. All commands can be run from the project root.

### Prerequisites & Setup

```sh
just ensure-infisical-config    # ensure Infisical config exists
just ensure-incus-token         # ensure Incus token exists (idempotent)
just ensure-kubeconfig          # ensure Kubernetes config exists (idempotent)
```

### Authentication

```sh
just auth                       # authenticate with Google Cloud and Infisical
```

### Host Configuration

```sh
just ansible                   # run Ansible playbook for host configuration
```

### Infrastructure Management

```sh
just init                      # initialize Terraform with backend config
just plan                      # plan Terraform changes
just apply                     # apply Terraform changes
just destroy                   # destroy Terraform-managed infrastructure
```

### Token & Config Management

```sh
just token-force               # force regenerate Incus authentication token
just kubeconfig-force          # force regenerate Kubernetes cluster configuration
just clean                     # remove all generated files and Terraform plans
```

### Command Dependencies

Commands have automatic dependency resolution:

- `ensure-kubeconfig` depends on `ensure-incus-token`
- `plan` and `apply` depend on `ensure-incus-token` and `ensure-kubeconfig`
- `kubeconfig-force` depends on `ensure-infisical-config` and `ensure-incus-token`

### Required Environment Variables

The following environment variables must be set:

- `INCUS_TOKEN_FILE`: Path to Incus token file (optional, defaults handled by scripts)
- `KUBECONFIG`: Path to Kubernetes config file (optional, defaults handled by scripts)

### Underlying Scripts

The justfile commands use the following bash scripts located in `scripts/`:

- `ensure-incus.sh`: Manages Incus authentication tokens and remote configuration
  - Supports `--force` flag to regenerate existing tokens
  - Automatically handles trusted machine detection and token generation
  - Configures Incus remote named 'k3s' and switches to it
- `ensure-kubeconfig.sh`: Fetches and configures Kubernetes cluster access
  - Supports `--force` flag to regenerate existing kubeconfig
  - Pulls kubeconfig from the master node via Incus
  - Updates server hostname for external access
- `lib/common.sh`: Shared utility functions for SSH operations, token validation, and error handling

Both scripts are idempotent - they only perform actions when necessary and can be safely run multiple times.

## Troubleshooting

### Common Issues

1. **Token generation fails**: Ensure Tailscale SSH is working and the user has Incus access on the target host
2. **Kubeconfig fetch fails**: Verify the K3s master container is running and accessible
3. **Terraform authentication errors**: Run `just auth` to re-authenticate with Google Cloud and Infisical
4. **Environment variable errors**: Ensure `.env` file exists with required variables or use `direnv allow`

### Force Regeneration

Use the `--force` flag with scripts to regenerate existing configurations:

```sh
just token-force          # Force regenerate Incus token
just kubeconfig-force     # Force regenerate kubeconfig
just clean                # Remove all generated files
```

### Debugging

- Check Incus connection: `incus list`
- Verify Tailscale connectivity: `tailscale ping k3s`
- Check Ansible connectivity: `ansible all -m ping`
- View container logs: `incus logs <container-name>`

## Configuration

### Terraform Variables

Variables in `terraform/variables.tf` can be customized:

- `cluster_name`: K3s cluster name (default: "k3s")
- `worker_count`: Number of worker nodes (default: 2)
- `container_image`: Base container image (default: "images:debian/13/cloud")
- `cpu_limit`: CPU limit per container (default: "5")
- `memory_limit`: Memory limit per container (default: "20GB")

### Sensitive Variables

Stored in Infisical and accessed via `infisical run`:

- `incus`: Incus server configuration
- `prefect_address`: Prefect server address
- `github`: GitHub integration tokens
- `tailscale`: Tailscale authentication key
- `infisical`: Infisical project credentials

### Ansible Configuration

- `inventory.ini`: Defines target hosts
- `playbook.yaml`: Host configuration tasks
- `.password`: Ansible become password (not tracked in git)

## Applications

- **Prefect**: Workflow orchestration
- **Airbyte**: Data integration
- **Infisical**: Secret management
- **Tailscale**: Secure networking with MagicDNS
- **SigNoz**: Application performance monitoring and observability
- **CloudSQL Proxy**: Secure connection to Google Cloud SQL databases
