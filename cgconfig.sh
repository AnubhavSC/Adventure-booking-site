#!/bin/bash

echo "=== Ubuntu Network & Tailscale Complete Fix ==="
echo "This script will:"
echo "1. Disable WiFi permanently"
echo "2. Configure only Ethernet"
echo "3. Fix Tailscale routing"
echo "4. Speed up boot time"
echo ""
read -p "Press Enter to continue..."

# 1. DISABLE WIFI PERMANENTLY
echo "Step 1: Disabling WiFi permanently..."
sudo rfkill block wifi
sudo systemctl disable wpa_supplicant
sudo systemctl mask wpa_supplicant

# Add WiFi to blacklist
echo "blacklist iwlwifi" | sudo tee -a /etc/modprobe.d/blacklist.conf
echo "blacklist iwlmvm" | sudo tee -a /etc/modprobe.d/blacklist.conf

# 2. CREATE CLEAN NETPLAN CONFIG (ETHERNET ONLY)
echo "Step 2: Creating clean Ethernet-only configuration..."
sudo cp /etc/netplan/01-netcfg.yaml /etc/netplan/01-netcfg.yaml.backup 2>/dev/null || true

cat << 'EOF' | sudo tee /etc/netplan/01-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp2s0f5:
      dhcp4: true
      dhcp4-overrides:
        route-metric: 100
        use-dns: true
      link-local: []
EOF

# Set correct permissions
sudo chmod 600 /etc/netplan/01-netcfg.yaml

# Remove old netplan files if they exist
sudo rm -f /etc/netplan/00-installer-config.yaml 2>/dev/null || true

# 3. CONFIGURE NETWORKD FOR FAST BOOT
echo "Step 3: Optimizing boot time..."
# Configure systemd-networkd-wait-online to only wait for ethernet
sudo mkdir -p /etc/systemd/system/systemd-networkd-wait-online.service.d/
cat << 'EOF' | sudo tee /etc/systemd/system/systemd-networkd-wait-online.service.d/override.conf
[Service]
ExecStart=
ExecStart=/lib/systemd/systemd-networkd-wait-online --interface=enp2s0f5 --timeout=30
EOF

# 4. DISABLE NETWORKMANAGER (CONFLICTS WITH NETWORKD)
echo "Step 4: Disabling NetworkManager to avoid conflicts..."
sudo systemctl stop NetworkManager
sudo systemctl disable NetworkManager
sudo systemctl mask NetworkManager

# 5. ENABLE SYSTEMD-NETWORKD
echo "Step 5: Enabling systemd-networkd..."
sudo systemctl enable systemd-networkd
sudo systemctl enable systemd-resolved

# 6. CONFIGURE TAILSCALE FOR CGNET BYPASS
echo "Step 6: Configuring Tailscale..."
# Create tailscale configuration directory
sudo mkdir -p /etc/systemd/system/tailscaled.service.d/

# Create tailscale override to start after network is ready
cat << 'EOF' | sudo tee /etc/systemd/system/tailscaled.service.d/override.conf
[Unit]
After=systemd-networkd.service network-online.target
Wants=network-online.target

[Service]
ExecStartPost=/bin/sleep 5
ExecStartPost=/usr/bin/tailscale up --accept-routes --accept-dns=false
Restart=on-failure
RestartSec=5
EOF

# 7. CREATE TAILSCALE RESTART SCRIPT FOR CGNET
echo "Step 7: Creating Tailscale optimization script..."
cat << 'EOF' | sudo tee /usr/local/bin/tailscale-cgnet-fix.sh
#!/bin/bash
# Tailscale CGNET bypass optimization

# Wait for network to be ready
sleep 10

# Restart tailscale with optimized settings
sudo systemctl restart tailscaled
sleep 5

# Connect with CGNET bypass settings
sudo tailscale up \
  --accept-routes \
  --accept-dns=false \
  --netfilter-mode=off \
  --advertise-exit-node

# Add custom routes to bypass CGNET restrictions
# Route Tailscale traffic through different interface if needed
TAILSCALE_IP=$(tailscale ip -4)
if [ ! -z "$TAILSCALE_IP" ]; then
    echo "Tailscale IP: $TAILSCALE_IP"
    # Add any custom routing rules here for CGNET bypass
fi

echo "Tailscale CGNET bypass configured"
EOF

sudo chmod +x /usr/local/bin/tailscale-cgnet-fix.sh

# 8. CREATE SYSTEMD SERVICE FOR TAILSCALE CGNET FIX
cat << 'EOF' | sudo tee /etc/systemd/system/tailscale-cgnet.service
[Unit]
Description=Tailscale CGNET Bypass Service
After=systemd-networkd.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/tailscale-cgnet-fix.sh
RemainAfterExit=yes
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable tailscale-cgnet.service

# 9. CLEANUP AND APPLY CHANGES
echo "Step 8: Applying all changes..."
# Remove any conflicting network configurations
sudo rm -rf /etc/NetworkManager/system-connections/* 2>/dev/null || true

# Apply netplan
sudo netplan apply

# Reload systemd
sudo systemctl daemon-reload

# 10. CREATE MANAGEMENT SCRIPTS
echo "Step 9: Creating management scripts..."

# Script to enable WiFi when needed
cat << 'EOF' | sudo tee /usr/local/bin/enable-wifi.sh
#!/bin/bash
echo "Enabling WiFi..."
sudo rfkill unblock wifi
sudo modprobe iwlwifi
sudo systemctl start wpa_supplicant
echo "WiFi enabled. Use 'nmcli device wifi connect SSID --ask' to connect"
EOF

sudo chmod +x /usr/local/bin/enable-wifi.sh

# Script to disable WiFi
cat << 'EOF' | sudo tee /usr/local/bin/disable-wifi.sh
#!/bin/bash
echo "Disabling WiFi..."
sudo rfkill block wifi
sudo systemctl stop wpa_supplicant
echo "WiFi disabled"
EOF

sudo chmod +x /usr/local/bin/disable-wifi.sh

# Script to check network status
cat << 'EOF' | sudo tee /usr/local/bin/check-network.sh
#!/bin/bash
echo "=== Network Status ==="
echo "Ethernet Status:"
ip addr show enp2s0f5 | grep -E "(state|inet)"
echo ""
echo "WiFi Status:"
rfkill list wifi
echo ""
echo "Tailscale Status:"
tailscale status
echo ""
echo "Routes:"
ip route show | head -5
EOF

sudo chmod +x /usr/local/bin/check-network.sh

echo ""
echo "=== SETUP COMPLETE ==="
echo ""
echo "REBOOT REQUIRED to apply all changes!"
echo ""
echo "After reboot:"
echo "- Only Ethernet will be active"
echo "- WiFi is permanently disabled"
echo "- Tailscale will auto-configure for CGNET bypass"
echo "- Boot time should be much faster"
echo ""
echo "Management commands:"
echo "- Enable WiFi when needed: sudo /usr/local/bin/enable-wifi.sh"
echo "- Disable WiFi: sudo /usr/local/bin/disable-wifi.sh"
echo "- Check network status: sudo /usr/local/bin/check-network.sh"
echo ""
echo "For CGNET bypass, after reboot run:"
echo "sudo tailscale up --accept-routes --advertise-exit-node"
echo ""
read -p "Reboot now? (y/N): " reboot_choice
if [[ $reboot_choice =~ ^[Yy]$ ]]; then
    sudo reboot
fi