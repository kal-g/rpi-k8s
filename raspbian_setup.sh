#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Add k8s repo
apt-get update
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list

# Install k8s and openvpn dependencies
apt-get update
apt-get install -y apt-transport-https gnupg2 kubelet kubeadm kubectl kubectl docker.io openvpn

# Disable updates for k8s packages
apt-mark hold kubelet kubeadm kubectl

# TODO Check and enable cgroups limit support
## docker info

# TODO Check and allow iptables to support bridged traffic
## /etc/sysctl.d/k8s.conf

# TODO Get opvn client config from server
