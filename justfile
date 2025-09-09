bucket := "bucket=iplanrio-dia-terraform"
tfplan := "terraform.tfplan"

# Authenticate with Google Cloud and Infisical
@auth:
    gcloud auth application-default login
    infisical login

# Run the Ansible playbook
@deploy:
    ansible-playbook -i inventory.ini playbook.yaml

# Test connection to all hosts
@ping:
    ansible all -i inventory.ini -m ping

# Forward Incus API port from remote to local
@incus-forward:
    ssh -f -N -L 8443:localhost:8443 k3s@k3s.squirrel-regulus.ts.net

# Forward K3s API port from remote to local (via master container)
@k3s-forward:
    ssh -f -N -L 6443:$(cd terraform && terraform output -raw k3s_master_ip):6443 k3s@k3s.squirrel-regulus.ts.net

# Stop all port forwarding processes
@stop-forward:
    -pkill -f "ssh.*k3s.squirrel-regulus.ts.net"

# Init Terraform with backend config
@init args="":
    cd terraform && terraform init -backend-config {{bucket}} -upgrade {{args}} -reconfigure

# Plan Terraform changes
@plan:
    cd terraform && infisical run -- terraform plan -out {{tfplan}}

# Destroy Terraform-managed infrastructure
@destroy:
    cd terraform && infisical run -- terraform destroy -auto-approve
# Apply Terraform changes
@apply:
    cd terraform && infisical run -- terraform apply {{tfplan}}
