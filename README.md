# 🏢 Enterprise IT Lab

A fully functional enterprise IT environment built from scratch on VMware Workstation.
Fully automated with PowerShell and Bash scripts.

## What's deployed

### Active Directory — Windows Server 2022
- Domain Controller for IB.local (DNS + DHCP integrated)
- 6 Organizational Units: IT, Finance, Management, Users, Computers, Service-Accounts
- 5 Domain Users assigned to groups across departments
- 4 Security Groups: GRP-IT, GRP-Finance, GRP-Management, GRP-AllUsers
- 6 GPOs: Password Policy, Screen Lock, Disable USB, Restrict Control Panel, Wallpaper, Disable CMD

### Client-01 — Windows 11
- Joined to IB.local domain
- GPOs applied automatically at login
- Tested with domain accounts: IB\a.admin, IB\s.finance, IB\k.manager

### Monitor-01 — Ubuntu 24.04 LTS
- Prometheus — metrics collection every 15 seconds
- Node Exporter — Linux system metrics (CPU, RAM, Disk, Network)
- Grafana — live dashboard accessible from any domain machine
- Windows Exporter — installed on DC01 for Windows metrics

### Graylog — Centralized Log Management
- MongoDB + OpenSearch + Graylog deployed via Docker Compose
- NXLog agents on DC01 and Client-01 forwarding Windows Event Logs (GELF/UDP)
- Automated deployment via GPO Software Installation
- Logs from both machines searchable in real time at http://192.168.1.101:9000

> Note: Wazuh SIEM was attempted first but abandoned due to persistent API/SSL
> crashes on Ubuntu 24.04 (both native and Docker install). Graylog was a clean
> deployment on the first attempt and covers the same centralized-logging need.

## Scripts

| Script | Language | What it does |
|--------|----------|--------------|
| AD-Setup.ps1 | PowerShell | Full AD setup: OUs, users, groups, DHCP, 6 GPOs |
| install-monitoring.sh | Bash | Prometheus + Node Exporter + Grafana install |
| graylog/docker-compose.yml | Docker Compose | MongoDB + OpenSearch + Graylog stack |
| graylog/nxlog.conf | NXLog config | Forwards Windows Event Logs to Graylog (GELF) |
| graylog/Deploy-NXLog-GPO.ps1 | PowerShell | Creates software share + GPO to deploy NXLog domain-wide |

## Infrastructure

| VM | OS | IP | Role |
|----|----|----|------|
| DC01 | Windows Server 2022 | 192.168.1.10 | Domain Controller, DNS, DHCP |
| Client-01 | Windows 11 | DHCP | Domain workstation |
| Monitor-01 | Ubuntu 24.04 | 192.168.1.101 | Prometheus, Grafana, Graylog |

## Tech Stack
Windows Server 2022 · Windows 11 · Ubuntu 24.04 · Active Directory · GPO ·
PowerShell · Bash · Docker · Prometheus · Grafana · Node Exporter ·
Graylog · NXLog · MongoDB · OpenSearch · VMware

## Coming next
- Graylog alerts (failed logon attempts, suspicious activity)
- VPN + AD integration (LDAP authentication)

## Author
Ayman Ibnousoufyane