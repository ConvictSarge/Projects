# Infrastructure as code for a Proxmox lab

![CI](https://github.com/ConvictSarge/Projects/actions/workflows/infrastructure-as-code.yml/badge.svg)

> Status: working. A full build, verify and teardown cycle has run on the live cluster: the VM was
> created from code, hardened by Ansible, checked (firewall, SSH policy, a second Ansible run that
> changed nothing, no drift), then destroyed. The teardown left no VM, disks or state behind, and
> nothing outside the pool changed. Next: remote state and more roles.

A way to build, configure and tear down lab VMs on a working Proxmox cluster from code, without any risk to the 40+ services already running on it. The code is in this folder.

## Pieces

- **OpenTofu** with the bpg/proxmox provider creates each VM from one reusable module: CPU, memory, disk, network and cloud-init, all from a short list of values.
- **cloud-init** sets the static address, DNS, admin user and SSH key on first boot. No installer, no clicking.
- **Ansible** applies a baseline: guest agent, automatic security updates, time sync, SSH hardening (no root, no passwords) and a default-deny firewall.
- **CI on every push:** format check, `tofu validate`, `ansible-lint` on its strictest profile, and a gitleaks secret scan.

## Keeping it away from production

The cluster already runs real services, so the safety model came first:

- The automation token is limited to one resource pool, two storages and one network bridge, and has read-only access to the node. Proxmox itself refuses anything outside that fence.
- The token works through the API only. No root SSH, and no node-level write access: the base image is downloaded once by an admin, and the code only references it.
- VM IDs must fall in a reserved range, enforced by validation in the module.
- OpenTofu never imports existing guests, so it can only change what it created.
- Every change is a saved `tofu plan` that gets reviewed before it is applied.
- State files, real settings and inventories never enter git.

## Lessons

- A loose version constraint pulled a provider release that was two days old. I now pin exact versions that have been out for at least two weeks and verify every download against its published checksum.
- The first version of the code needed root SSH on the node to import disks. Switching to the API's import feature removed that need and shrank the token's permissions.
- My first apply was refused with a 403 even though every ACL was in place. A privilege-separated Proxmox token gets only the overlap of its own permissions and its user's, and the user had none. The fix was granting the same scoped ACLs to the user, which keeps the fence intact.
- The create then failed partway through, after the disks were built. Proxmox checks tag permissions against the new VM before it joins its pool, so a pool-scoped token cannot set tags at create time. I dropped tags and mark ownership with pool membership and a description instead. Proxmox cleaned up the half-built disks on its own, which I confirmed.
- The Ubuntu cloud image does not include the QEMU guest agent, so OpenTofu sat waiting for it. Running the Ansible baseline installed the agent and let the apply finish. The second Ansible run changed nothing, which is the point.
- Before choosing where to build, I checked both nodes. One was deep into swap, so the lab went on the other.

## What is in this folder

```
terraform/            root module: VM definitions, optional image download
terraform/modules/vm  reusable VM module (reserved ID range, cloud-init)
ansible/              inventory example, baseline playbook and role
docs/                 architecture, safety model, runbook
scripts/              stores the API token in a private env file without echoing it
```

CI for this folder: [`.github/workflows/infrastructure-as-code.yml`](../.github/workflows/infrastructure-as-code.yml).

## Quick start

```bash
# One-time Proxmox setup (pool, role, scoped token, cloud image): docs/runbook.md
bash scripts/set-token.sh
set -a; . ~/.config/homelab-iac/env; set +a

cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit values
tofu init
tofu plan -out lab.plan                        # review it
tofu apply lab.plan

cd ../ansible
cp inventory/hosts.example.yml inventory/hosts.yml
ansible-galaxy collection install -r requirements.yml
ansible-playbook playbooks/baseline.yml

cd ../terraform && tofu destroy
```

Details: [architecture](docs/architecture.md), [safety model](docs/safety.md), [runbook](docs/runbook.md).

## Stack

Proxmox VE, OpenTofu, cloud-init, Ansible, GitHub Actions, gitleaks.
