#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to check if script is run as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root" 1>&2
        exit 1
    fi
}

# Function to update the system
update_system() {
    echo "Updating the system..."
    apt update && apt dist-upgrade -y
}

# Function to install dependencies
install_dependencies() {
    echo "Installing dependencies..."
    apt install -y sudo wget net-tools sudo bmon build-essential libssl-dev liblzo2-dev libpam0g-dev easy-rsa git openssl lz4 gcc cmake telnet curl make lsof
}

# Function to download and prepare OpenVPN source
prepare_openvpn_source() {
    echo "Preparing OpenVPN source..."
    mkdir -p /opt/openvpn_install && cd /opt/openvpn_install
    wget https://raw.githubusercontent.com/Tunnelblick/Tunnelblick/master/third_party/sources/openvpn/openvpn-2.5.9/openvpn-2.5.9.tar.gz
    tar xvf openvpn-2.5.9.tar.gz
    cd openvpn-2.5.9
}

# Function to download and apply patches
download_and_apply_patches() {
    echo "Downloading and applying patches..."
    local patches=(
        "02-tunnelblick-openvpn_xorpatch-a.diff"
        "03-tunnelblick-openvpn_xorpatch-b.diff"
        "04-tunnelblick-openvpn_xorpatch-c.diff"
        "05-tunnelblick-openvpn_xorpatch-d.diff"
        "06-tunnelblick-openvpn_xorpatch-e.diff"
    )

    for patch in "${patches[@]}"; do
        wget "https://raw.githubusercontent.com/Tunnelblick/Tunnelblick/master/third_party/sources/openvpn/openvpn-2.5.9/patches/$patch"
        git apply "$patch"
    done
}

# Function to compile and install OpenVPN
compile_and_install_openvpn() {
    echo "Compiling and installing OpenVPN..."
    ./configure
    make
    make install
    ln -sf /usr/local/sbin/openvpn /usr/sbin/openvpn
}

# Function to enable IP forwarding
enable_ip_forwarding() {
    echo "Enabling IP forwarding..."
    echo "net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
    sysctl -p
}

# Function to create and install OpenVPN service file
create_service_file() {
    local service_file="/lib/systemd/system/openvpn@.service"
    
    echo "Removing existing OpenVPN service file (if any)..."
    rm -f "$service_file"
    
    echo "Creating new OpenVPN service file..."
    cat > "$service_file" << EOL
[Unit]
Description=OpenVPN connection to %i
PartOf=openvpn.service
Before=systemd-user-sessions.service
After=network-online.target
Wants=network-online.target
Documentation=man:openvpn(8)
Documentation=https://community.openvpn.net/openvpn/wiki/Openvpn24ManPage
Documentation=https://community.openvpn.net/openvpn/wiki/HOWTO

[Service]
Type=simple
PrivateTmp=true
WorkingDirectory=/etc/openvpn
ExecStartPre=/bin/mkdir -p /run/openvpn
ExecStartPre=/bin/chown root:root /run/openvpn
ExecStart=/usr/sbin/openvpn --daemon ovpn-%i --status /run/openvpn/%i.status 10 --cd /etc/openvpn --config /etc/openvpn/%i.conf --writepid /run/openvpn/%i.pid
PIDFile=/run/openvpn/%i.pid
KillMode=process
CapabilityBoundingSet=CAP_IPC_LOCK CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SETGID CAP_SETUID CAP_SYS_CHROOT CAP_DAC_OVERRIDE CAP_AUDIT_WRITE
LimitNPROC=100
DeviceAllow=/dev/null rw
DeviceAllow=/dev/net/tun rw
ProtectSystem=true
ProtectHome=true
RestartSec=5s
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

    echo "New OpenVPN service file has been created."

    echo "Reloading systemd daemon"
    systemctl daemon-reload
}

# Main function
main() {
    check_root
    update_system
    install_dependencies
    prepare_openvpn_source
    download_and_apply_patches
    compile_and_install_openvpn
    #enable_ip_forwarding
    create_service_file
    echo "OpenVPN with XOR patch has been installed successfully!"
    echo "The OpenVPN service has been created and enabled."
    #echo "You can start it with: systemctl start openvpn@server"
    #echo "Make sure you have created the server configuration file at /etc/openvpn/server.conf before starting the service."
}

# Run the main function
main
