# Infrastructure & Configuration Management with Terraform + Ansible

End-to-end IaC pipeline that provisions an AWS EC2 instance with Terraform and configures it with Ansible. Built as part of the [roadmap.sh DevOps projects](https://roadmap.sh/projects/configuration-management).

## Stack

| Tool | Role |
|------|------|
| **Terraform** | Provision EC2 instance, Security Group, Key Pair |
| **Ansible** | Configure the server (nginx, app deploy, SSH hardening) |

## How it works

```
terraform apply → EC2 instance ready → ansible-playbook → fully configured server
```

Terraform provisions the infrastructure and outputs the public DNS. Ansible picks it up via `inventory.ini` and runs 4 roles in sequence:

| Role | What it does |
|------|-------------|
| `base` | apt update, installs utilities, enables `fail2ban` |
| `nginx` | Installs nginx, deploys Jinja2-templated config |
| `app` | Uploads and extracts static website to `/var/www/html` |
| `ssh` | Adds public key to `authorized_keys` |

## Project Structure

```
.
├── terraform/
│   ├── main.tf            # EC2, Security Group, Key Pair resources
│   ├── variables.tf       # Region, AMI, instance type
│   └── outputs.tf         # Public IP, DNS, SSH command, Ansible inventory line
├── inventory.ini          # Target server(s)
├── setup.yml              # Main Ansible playbook
└── roles/
    ├── base/
    ├── nginx/
    ├── app/
    └── ssh/
```

## Requirements

- Terraform >= 1.0
- Ansible installed locally
- AWS credentials configured (`~/.aws/credentials`)
- `.pem` key file for EC2 authentication

## Usage

### 1. Provision infrastructure

```bash
cd terraform
terraform init
terraform apply
```

### 2. Update inventory

Copy the `ansible_inventory` output from Terraform into `inventory.ini`:

```ini
[servers]
ec2-xx-xx-xx-xx.region.compute.amazonaws.com ansible_user=ubuntu ansible_ssh_private_key_file=./config-manager.pem
```

### 3. Configure the server

```bash
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini setup.yml
```

### Teardown

```bash
cd terraform && terraform destroy
```

## Notes

- `.pem` files and SSH keys are excluded from version control via `.gitignore`
- `become: yes` is set at playbook level for privilege escalation

