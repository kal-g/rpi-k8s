#!/bin/bash

CYAN='\033[0;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

if [[ -f ".rpi-k8s" ]]; then
  NODE_NAME=`sed "1q;d" .rpi-k8s`
  NODE_IP=`sed "2q;d" .rpi-k8s`
else
  echo "No previous config found"
  read -p "NODE_NAME=" NODE_NAME
  read -p "NODE_IP=" NODE_IP
  echo $NODE_NAME >> .rpi-k8s
  echo $NODE_IP >> .rpi-k8s
fi

echo "Setting up node with info:"
echo "Name: $NODE_NAME"
echo "IP: $NODE_IP"

# Add k8s repo
if [[ ! -f "/etc/apt/sources.list.d/kubernetes.list" ]]; then
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
fi

# Install k8s and openvpn dependencies
echo "Updating packages"
apt-get update
apt-get install -y apt-transport-https gnupg2 kubelet kubeadm kubectl kubectl docker.io openvpn

# Disable updates for k8s packages
apt-mark hold kubelet kubeadm kubectl

# Check and enable cgroups limit support
if [[ ! -f "/etc/docker/daemon.json" ]]; then
  cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
  sed -i '$ s/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 swapaccount=1/' /boot/cmdline.txt
fi

# Check and allow iptables to support bridged traffic
if [[ ! -f "/etc/sysctl.d/k8s.conf" ]]; then
  cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
  net.bridge.bridge-nf-call-ip6tables = 1
  net.bridge.bridge-nf-call-iptables = 1
EOF
  sysctl --system
fi

# Disable swap
systemctl disable dphys-swapfile.service

# Get opvn client config from server
OVPN_CONF="/etc/openvpn/$NODE_NAME.conf"
if [[ ! -f $OVPN_CONF ]]; then
  echo -e "${CYAN}Place the ovpn config at $OVPN_CONF and rerun this script ${NC}"
  exit
fi

if [[ ! -f "/etc/sysctl.d/k8s.conf" ]]; then
  cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
  net.bridge.bridge-nf-call-ip6tables = 1
  net.bridge.bridge-nf-call-iptables = 1
EOF
  sysctl --system
fi

if [[ ! -f "/etc/default/kubelet" ]]; then
  cat <<EOF | sudo tee /etc/default/kubelet
  KUBELET_EXTRA_ARGS="--node-ip=$NODE_IP --hostname-override=$NODE_NAME"
EOF
fi

# Start ovpn client
CMD="systemctl restart openvpn@$NODE_NAME.service"
sudo systemctl daemon-reload
$CMD
sudo systemctl restart kubelet

echo "Finished setup successfully"
