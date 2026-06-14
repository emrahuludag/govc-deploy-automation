# govc-deploy-automation

Automated VM deployment tool for VMware vSphere environments using [govc](https://github.com/vmware/govmomi/tree/main/govc) (Go-based vSphere CLI). Supports bulk provisioning of Linux and Windows virtual machines from CSV inventory files.

---

## Features

- Bulk VM deployment from CSV — Linux and Windows in separate workflows
- Automatic folder creation in vSphere inventory
- VM customization: hostname, IP, DNS, domain, gateway
- CPU, memory, and multi-disk configuration (up to 3 disks)
- VM annotation with deployment date, environment, and team
- IP readiness check with configurable timeout
- Interactive menu with vCenter connection prompt
- Built-in `govc` installation option

---

## Project Structure

```
govc-deploy-automation/
├── govc-vm-deploy.sh        # Main entry point (interactive menu)
├── bin/
│   ├── deploy_linux.sh      # Linux VM deployment logic
│   └── deploy_windows.sh    # Windows VM deployment logic
└── vms/
    ├── linuxvm.csv          # Linux VM inventory
    └── msvm.csv             # Windows VM inventory
```

---

## Requirements

- Linux/macOS shell environment (bash)
- `govc` binary — can be installed via menu option `[3]`
- vSphere account with VM provisioning privileges
- A pre-built VM template (RHEL, Ubuntu, Windows Server, etc.)
- VMware Tools must be installed on the template (required for IP readiness check and customization)

---

## Getting Started

```bash
git clone https://github.com/emrahuludag/govc-deploy-automation.git
cd govc-deploy-automation
chmod +x govc-vm-deploy.sh bin/*.sh
./govc-vm-deploy.sh
```

Menu options:

```
[1] Deploy Linux
[2] Deploy Windows
[3] Install govc on Linux
[q] Quit
```

---

## CSV Inventory Format

Both Linux and Windows inventories use `;` as the delimiter.

### Linux — `vms/linuxvm.csv`

| Field    | Description                        | Example          |
|----------|------------------------------------|------------------|
| folder   | vSphere VM folder name             | Unix             |
| vmname   | VM display name in vCenter         | tr-lb01          |
| hostname | Guest OS hostname (FQDN)           | tr-lb01          |
| osdisk   | OS disk size (GB) — template disk  | 100              |
| disk1    | Primary data disk (GB)             | 150              |
| disk2    | Secondary data disk (GB, 0=skip)   | 0                |
| disk3    | Third data disk (GB, 0=skip)       | 0                |
| cpu      | vCPU count                         | 4                |
| memory   | RAM in GB                          | 16               |
| vlan     | Port group / VLAN name             | VLAN_70          |
| ip       | Static IP address                  | 10.20.10.1       |
| netmask  | Subnet mask                        | 255.255.255.0    |
| gw       | Default gateway                    | 10.20.10.254     |
| dns1     | Primary DNS server                 | 10.10.11.1       |
| dns2     | Secondary DNS server               | 10.10.11.2       |
| domain   | DNS domain / search suffix         | domain.local     |
| vmenv    | Environment label (annotation)     | prod             |
| vmteam   | Team label (annotation)            | unix             |

**Example:**
```csv
folder;vmname;hostname;osdisk;disk1;disk2;disk3;cpu;memory;vlan;ip;netmask;gw;dns1;dns2;domain;vmenv;vmteam
Unix;tr-lb01;tr-lb01;100;150;0;0;4;16;VLAN_70;10.20.10.1;255.255.255.0;10.20.10.254;10.10.11.1;10.10.11.2;domain.local;prod;unix
```

### Windows — `vms/msvm.csv`

Same column layout as Linux. The `domain` field is present in the CSV but Windows domain join must be handled separately (via Sysprep answer file or post-deployment script).

**Example:**
```csv
folder;vmname;hostname;osdisk;disk1;disk2;disk3;cpu;memory;vlan;ip;netmask;gw;dns1;dns2;domain;vmenv;vmteam
Microsoft;tr-db01;tr-db01;150;0;0;0;4;32;VLAN_70;10.10.10.1;255.255.255.0;10.10.10.254;10.10.0.1;10.10.0.12;domain.local;prod;microsoft
```

> **Note:** Set `disk2` and `disk3` to `0` to skip additional disk creation.

---

## Runtime Inputs

When running either deployment script, you will be prompted for:

| Prompt              | Description                                      |
|---------------------|--------------------------------------------------|
| vCenter URL         | e.g. `https://vcenter.example.local`             |
| vCenter Username    | e.g. `administrator@vsphere.local`               |
| vCenter Password    | Entered securely (hidden input)                  |
| Datacenter          | vSphere datacenter name, e.g. `TR_DC`            |
| Cluster             | vSphere cluster name, e.g. `TR_CLS`              |
| Datastore           | Target datastore, e.g. `TR-DS01`                 |
| Template Name       | VM template name, e.g. `RH9_tmp`, `W2022_tmp`   |

---

## Deployment Flow

```
Read CSV row
    │
    ├─▶ Create vSphere folder (if not exists)
    ├─▶ Clone VM from template
    ├─▶ Add VMXNET3 NIC and connect
    ├─▶ Set CPU / Memory
    ├─▶ Add extra disks (disk2, disk3 if > 0)
    ├─▶ Apply guest customization (hostname, IP, DNS)
    ├─▶ Set VM annotation (date, env, team)
    ├─▶ Power on VM
    └─▶ Wait for IP (timeout: 5 min) → Print summary
```

---

## Notes

- `GOVC_INSECURE=1` is set by default — self-signed vCenter certificates are accepted.
- The script uses `set -euo pipefail`; any govc error will halt execution immediately.
- IP wait timeout is 5 minutes per VM (`govc vm.ip -wait 5m`).
- For Linux, `vmware-toolsd` must be running on the template for customization to apply correctly.
- For Windows, VMware Tools and a valid Sysprep configuration on the template are required.

---

## Author

**Emrah Uludag**  
Senior Linux Platforms & Cloud Systems Administrator  
[github.com/emrahuludag](https://github.com/emrahuludag)

---

## License

This project is free and open source. You are free to use, modify, and distribute it for any purpose — personal, commercial, or otherwise — without restriction and without needing to ask for permission.
