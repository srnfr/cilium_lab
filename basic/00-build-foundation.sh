#!/bin/bash
set +x

apt update
apt install -y bridge-utils jq tcpdump curl git golang docker-ce docker-ce-cli

## Open Files
cat << EOF | sudo tee /etc/sysctl.d/99-inotify.conf
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=1024
EOF
sysctl -p /etc/sysctl.d/99-inotify.conf

## nginx
cp /home/cilium_lab/nginx/* /etc/nginx/sites_enabled/
rm -f /etc/nginx/sites-enabled/default 
systemctl restart nginx

## k alias
echo "alias k=kubectl" >> ~/.bashrc
echo "complete -F __start_kubectl k" >> ~/.bashrc

## Containerlab
bash -c "$(curl -sL https://get.containerlab.dev)"

##kubctl
curl -s -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl && kubectl version --client

## Kind
curl -s -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind

## Install Cilium et autres
  export CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)
  export GOOS=linux
  export GOARCH=amd64
  curl -s -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-${GOOS}-${GOARCH}.tar.gz{,.sha256sum}
  sha256sum --check cilium-${GOOS}-${GOARCH}.tar.gz.sha256sum
  sudo tar -C /usr/local/bin -xzvf cilium-${GOOS}-${GOARCH}.tar.gz
  rm -f cilium-*.tar.gz{,.sha256sum}

## Hubble cli
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
  HUBBLE_ARCH=amd64
  if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
  curl -s -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
  sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
  sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
  rm -f hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}

# install helm
curl -s https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

#install nsenter
cd /home/cilium_lab
git clone https://github.com/alexei-led/nsenter.git

kind version
kubectl version
cilium version
hubble version
helm version
