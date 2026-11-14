# Safety model

This repo runs against a cluster that also hosts production services. These controls keep
it from touching anything it does not own.

| Control | Enforced by | Failure it prevents |
|---|---|---|
| API token limited to the `iac-lab` pool | Proxmox permissions | Editing or deleting any guest outside the pool |
| VMID must be 9000-9099 | Variable validation in `modules/vm` | Colliding with an existing guest's ID |
| Every VM in the `iac-lab` pool with a "Managed by OpenTofu" description | Module default | Confusion about who owns a VM in the UI |
| No `tofu import` of existing guests | Policy | Existing guests entering state and being changed or destroyed |
| `tofu plan -out` then apply that plan | Makefile / runbook | Surprise changes between review and apply |
| State, tfvars, real inventory git-ignored | `.gitignore` | Leaking addresses, tokens or keys |
| gitleaks on every push | CI | Secrets slipping in anyway |

## Proxmox role for the token

The token is privilege-separated and holds role `IaCLab` only on:

| Path | Why |
|---|---|
| `/pool/iac-lab` | Create, configure, start, stop, delete its own VMs |
| `/storage/<vm store>` and `/storage/<image store>` | Allocate disks, read the cloud image |
| `/sdn/zones/localnetwork/<bridge>` | Attach NICs to one bridge |
| `/nodes/<node>` (PVEAuditor, read-only) | Read node status |

It has no `Sys.Modify`, no root SSH, and nothing on `/`. The cloud image is downloaded once
by an admin so the token never needs node-level write access. Exact commands:
[runbook.md](runbook.md).
