#!/bin/bash
# ============================================================
# install-monitoring.sh
# Grafana + Prometheus + Node Exporter + Wazuh Agent
# Author: Ayman Ibnousoufyane
# Monitor-01 | Ubuntu 24.04
# ============================================================

set -e
echo "============================================"
echo "   Monitoring Stack Installation"
echo "   By Ayman Ibnousoufyane"
echo "============================================"

# ── 1. Prometheus ─────────────────────────────
echo "[1/4] Installing Prometheus..."
sudo useradd --no-create-home --shell /bin/false prometheus 2>/dev/null || true
sudo mkdir -p /etc/prometheus /var/lib/prometheus

cd /tmp
wget -q https://github.com/prometheus/prometheus/releases/download/v2.51.0/prometheus-2.51.0.linux-amd64.tar.gz
tar xf prometheus-2.51.0.linux-amd64.tar.gz
sudo cp prometheus-2.51.0.linux-amd64/prometheus /usr/local/bin/
sudo cp prometheus-2.51.0.linux-amd64/promtool /usr/local/bin/
sudo cp -r prometheus-2.51.0.linux-amd64/consoles /etc/prometheus/
sudo cp -r prometheus-2.51.0.linux-amd64/console_libraries /etc/prometheus/

sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'windows-dc01'
    static_configs:
      - targets: ['192.168.1.10:9182']

  - job_name: 'windows-client01'
    static_configs:
      - targets: ['192.168.1.101:9182']
EOF

sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
echo "   [+] Prometheus running on port 9090"

# ── 2. Node Exporter ──────────────────────────
echo "[2/4] Installing Node Exporter..."
cd /tmp
wget -q https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xf node_exporter-1.7.0.linux-amd64.tar.gz
sudo cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
sudo useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true

sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
echo "   [+] Node Exporter running on port 9100"

# ── 3. Grafana ────────────────────────────────
echo "[3/4] Installing Grafana..."
sudo apt-get install -y apt-transport-https software-properties-common wget curl gnupg2
sudo mkdir -p /etc/apt/keyrings
wget -q -O - https://apt.grafana.com/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update -q
sudo apt-get install -y grafana
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
echo "   [+] Grafana running on port 3000"

# ── 4. Wazuh Agent ────────────────────────────
echo "[4/4] Installing Wazuh Agent..."
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
sudo chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list
sudo apt-get update -q
sudo WAZUH_MANAGER='192.168.1.20' apt-get install -y wazuh-agent
sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
echo "   [+] Wazuh Agent installed"

# ── Summary ───────────────────────────────────
echo ""
echo "============================================"
echo "        INSTALLATION COMPLETE!"
echo "============================================"
echo ""
echo "Services running:"
echo "  Prometheus  : http://192.168.1.101:9090"
echo "  Node Export : http://192.168.1.101:9100"
echo "  Grafana     : http://192.168.1.101:3000"
echo "  Wazuh Agent : connected to 192.168.1.20"
echo ""
echo "Grafana login:"
echo "  User    : admin"
echo "  Password: admin"
echo ""
echo "Next: Open Grafana on Client-01 browser!"
echo "============================================"