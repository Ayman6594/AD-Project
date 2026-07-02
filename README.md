# Enterprise IT Lab — Ibnousoufyane Ayman

A fully functional enterprise IT environment built from scratch on VMware Workstation.  
Every component was manually configured, scripted where possible, tested, and documented with evidence.

**Documentation:** [`Enterprise_IT_Lab_Ibnousoufyane_Ayman_FINAL.pdf`](./Enterprise_IT_Lab_Ibnousoufyane_Ayman_FINAL.pdf)

---

## Lab Architecture

| VM | OS | IP Address | RAM | Role |
|---|---|---|---|---|
| DC01 | Windows Server 2022 | 192.168.1.10 | 4 GB | Domain Controller, DNS, DHCP |
| Client-01 | Windows 11 | 192.168.1.x (DHCP) | 4 GB | Domain workstation |
| Monitor-01 | Ubuntu 24.04 LTS | 192.168.1.101 | 4 GB | Prometheus, Grafana, Graylog, VPN |

Four VMs communicate over a Host-Only internal network with internet access via NAT.

---

## Stack

| Domain | What Was Built |
|---|---|
| Sysadmin | Active Directory, GPO, DHCP, DNS, OU structure, domain users |
| Endpoint | Windows 11 domain join, GPO enforcement verified on workstation |
| Monitoring | Prometheus + Grafana + Node Exporter, live dashboard |
| SIEM | Graylog + NXLog, centralized Windows event log collection |
| Security | Brute-force alerting on Event ID 4625, HTTP webhook in real time |
| VPN | ocserv SSL VPN + PAM-LDAP authentication against Active Directory |
| IaC | PowerShell automation script, bash install script, GPO software deploy |

---

## Section 1 — Active Directory

Windows Server 2022 promoted as Domain Controller for `IB.local`.  
Full configuration automated via a single PowerShell script.

**Script:** `AD-Setup.ps1`

```powershell
Set-ExecutionPolicy Unrestricted -Force
.\AD-Setup.ps1
```

What the script creates:
- 6 Organizational Units: IB-Company, IT, Finance, Management, Users, Computers, Service-Accounts
- 4 Security Groups: GRP-IT, GRP-Finance, GRP-Management, GRP-AllUsers
- 5 Domain Users assigned to their respective OUs and groups
- DHCP Server installed, authorized, and scope configured
- 6 GPOs created and linked to their target OUs

**GPOs deployed:**

| GPO | Target | Effect |
|---|---|---|
| GPO-PasswordPolicy | IB.local | Strong password + 90-day expiry |
| GPO-ScreenLock | IB-Company | Screen locks after 10 minutes |
| GPO-Wallpaper | IB-Company | Company wallpaper on all machines |
| GPO-DisableUSB | Finance OU | USB storage blocked |
| GPO-RestrictControlPanel | Finance OU | Control Panel inaccessible |
| GPO-DisableCMD | Finance OU | CMD and PowerShell blocked |

---

## Section 2 — Client-01 Domain Workstation

Windows 11 joined to `IB.local`. All GPOs apply automatically at login.

Domain join steps:
1. Host-Only adapter added in VMware
2. DNS set to 192.168.1.10 (DC01)
3. System Properties > Change > Domain: IB.local
4. Authenticated with `IB\Administrateur`
5. Verified with `IB\a.admin` and `IB\s.finance`

GPO verification on Finance account (`s.finance`):
- CMD: disabled by administrator
- Control Panel: blocked by restrictions
- USB storage: blocked by system

---

## Section 3 — Monitoring — Prometheus + Grafana

**Script:** `install-monitoring.sh`

```bash
chmod +x ~/install-monitoring.sh
sudo ~/install-monitoring.sh
```

Services installed:
- Prometheus at `/usr/local/bin/prometheus` — port 9090
- Node Exporter at `/usr/local/bin/node_exporter` — port 9100
- Grafana via official apt repository — port 3000
- Windows Exporter on DC01 via PowerShell — port 9182

**Access:** http://192.168.1.101:3000 — `admin / User@123456`

Metrics collected every 15 seconds: CPU per core, RAM, Disk I/O, Network bandwidth, System load, Filesystem usage.

---

## Section 4 — Graylog Centralized Log Management

Deployed via Docker Compose (3 containers: MongoDB, OpenSearch, Graylog).

**Access:** http://192.168.1.101:9000 — `admin / admin`

```bash
mkdir -p ~/graylog && cd ~/graylog
sudo docker-compose up -d
```

NXLog Community Edition installed on DC01 and Client-01 to forward Windows Event Logs (Application, System, Security) to Graylog via GELF/UDP on port 12201.

NXLog key config:
```
Module om_udp
Host 192.168.1.101
Port 12201
OutputType GELF
```

NXLog deployed automatically via GPO (`GPO-Deploy-NXLog`) using Software Installation from `\\DC01\Software\nxlog.msi`.

Log sources confirmed working:
- `DC01.IB.local`: logon/logoff, special privileges, service events
- `Client-01.IB.local`: system events, network configuration changes

---

## Section 5 — Graylog Alerts — Brute-Force Detection

Stream `Failed-Logons` filters Event ID 4625 using range rules:
- `EventID > 4624` AND `EventID < 4626`

Event Definition: triggers when `count() > 4` on `TargetUserName` within 5 minutes.

HTTP webhook receiver on Monitor-01 (port 5001):
```bash
python3 ~/graylog-webhook.py &
```

Notification URL: `http://172.18.0.1:5001/alert` (Docker gateway)

**Test result:** 6 failed logins on `Administrateur` → alert fired automatically:
```
ALERT RECEIVED
  Title   : Brute-Force Detected - 4625
  Account : Brute-Force Detected - 4625: Administrateur - count()=6.0
```

---

## Section 6 — VPN SSL + Active Directory/LDAP

ocserv 1.2.4 deployed on Monitor-01, port 443 TCP/UDP.  
Authentication via PAM-LDAP against DC01 (`DC=IB,DC=local`).

```bash
sudo apt install -y ocserv libpam-ldap nscd
```

Certificate generated with GnuTLS certtool (3072-bit RSA, 10-year validity).

LDAP verified before VPN config:
```bash
ldapsearch -x -H ldap://192.168.1.10 \
  -D "IB\Administrateur" -w "***" \
  -b "DC=IB,DC=local" "(sAMAccountName=a.admin)" cn
# result: 0 Success
```

Test connection: `a.admin` authenticated with AD credentials → IP `10.10.10.181` assigned, DNS `192.168.1.10` pushed, route `192.168.1.0/24` accessible.

---

## Services and Access

| Service | URL | Credentials |
|---|---|---|
| Grafana | http://192.168.1.101:3000 | admin / User@123456 |
| Prometheus | http://192.168.1.101:9090 | No auth |
| Node Exporter | http://192.168.1.101:9100/metrics | No auth |
| Graylog | http://192.168.1.101:9000 | admin / admin |
| ocserv VPN | 192.168.1.101:443 | AD credentials via PAM-LDAP |
| DC01 RDP | 192.168.1.10 | IB\Administrateur |

---

## Tech Stack

```
Windows Server 2022  Active Directory · DNS · DHCP · GPO · PowerShell
Windows 11           Domain workstation · GPO enforcement
Ubuntu 24.04 LTS     Prometheus · Grafana · Graylog · ocserv · Docker
NXLog CE             Windows Event Log forwarding (GELF/UDP)
```

---

## Author

**Ibnousoufyane Ayman**  
July 2026
