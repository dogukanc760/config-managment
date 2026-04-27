# Configuration Management with Ansible

An Ansible playbook project that automates the configuration of a Linux server on AWS EC2. Built as part of the [roadmap.sh DevOps projects](https://roadmap.sh/projects/configuration-management).

## What it does

Runs 4 roles in sequence to fully configure a fresh Ubuntu server:

| Role | Description |
|------|-------------|
| `base` | Updates apt cache, installs utilities (`curl`, `vim`, `ufw`), sets up `fail2ban` |
| `nginx` | Installs and enables nginx, deploys config via Jinja2 template |
| `app` | Uploads and extracts a static HTML website to `/var/www/html` |
| `ssh` | Adds a public key to the server's `authorized_keys` |

## Project Structure

```
.
├── inventory.ini          # Target server(s)
├── setup.yml              # Main playbook
└── roles/
    ├── base/tasks/
    ├── nginx/tasks/ & templates/ & handlers/
    ├── app/tasks/ & files/
    └── ssh/tasks/
```

## Requirements

- Ansible installed locally (`brew install ansible` on macOS)
- An Ubuntu server with SSH access (tested on AWS EC2)
- `.pem` key file for EC2 authentication

## Usage

```bash
# Run all roles
ansible-playbook setup.yml -i inventory.ini

# Run a specific role only
ansible-playbook setup.yml -i inventory.ini --tags "nginx"
```

## Setup

1. Update `inventory.ini` with your server's IP and key path
2. Place your static site files in `roles/app/files/website.tar.gz`
3. Run the playbook

## Notes

- `.pem` files and SSH keys are excluded from version control via `.gitignore`
- `become: yes` is set at playbook level for privilege escalation

