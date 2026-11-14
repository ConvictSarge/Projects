# Runbook

## First-time setup (on a Proxmox node shell, as root)

Set `NODE`, `VMSTORE`, `IMGSTORE` and `BRIDGE` for your cluster first.

```bash
NODE=pve; VMSTORE=local-lvm; IMGSTORE=local; BRIDGE=vmbr0

# Guest-agent read privilege was renamed in Proxmox VE 9
if pveversion | grep -q 'pve-manager/9'; then AGENT=VM.GuestAgent.Audit; else AGENT=VM.Monitor; fi

# 1. Pool, role, user, token (token is privilege-separated: it gets only what the ACLs below grant)
pveum pool add iac-lab --comment "Managed by homelab-iac"
pveum role add IaCLab -privs "VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.PowerMgmt $AGENT Datastore.AllocateSpace Datastore.Audit SDN.Use Pool.Audit Sys.Audit"
pveum user add tofu@pve --comment "homelab-iac automation"
pveum user token add tofu@pve iac --privsep 1     # secret is shown ONCE: save it in your password manager

# 2. Scope it: the pool, the two storages, the one bridge, read-only on the node.
#    A privilege-separated token gets the INTERSECTION of its own ACLs and its user's,
#    so the same ACLs go on both the user and the token.
for who in "--users tofu@pve" "--tokens tofu@pve!iac"; do
  pveum acl modify /pool/iac-lab                   $who --roles IaCLab
  pveum acl modify /storage/$VMSTORE               $who --roles IaCLab
  pveum acl modify /storage/$IMGSTORE              $who --roles IaCLab
  pveum acl modify /sdn/zones/localnetwork/$BRIDGE $who --roles IaCLab
  pveum acl modify /nodes/$NODE                    $who --roles PVEAuditor
done

# 3. Cloud image, downloaded once by root into the import store
pvesh create /nodes/$NODE/storage/$IMGSTORE/download-url --content import \
  --filename noble-server-cloudimg-amd64.qcow2 \
  --url https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# 4. Prove the fence: this must list nothing outside the pool
pveum user token permissions tofu@pve iac
```

On the workstation, export the token only in your shell:

```bash
export PROXMOX_VE_ENDPOINT="https://pve.example.lan:8006/"
export PROXMOX_VE_API_TOKEN="tofu@pve!iac=<secret from the password manager>"
```

## Build or change the lab

```bash
make plan      # review every line
make apply
make configure
```

## Rebuild one VM from scratch

```bash
tofu -chdir=terraform apply -replace='module.vm["lab-web-01"].proxmox_virtual_environment_vm.this'
make configure
```

## Tear down

```bash
make destroy   # only removes VMs in state, never anything else
```

## Remove the scaffolding entirely

```bash
pveum user token remove tofu@pve iac
pveum user delete tofu@pve
pveum role delete IaCLab
pveum pool delete iac-lab    # only once the pool is empty
```
