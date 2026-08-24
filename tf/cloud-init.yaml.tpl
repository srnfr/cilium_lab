#cloud-config

# Mise à jour du système
package_update: true
package_upgrade: true

# Ajout du repo Docker officiel
apt:
  sources:
    docker.list:
      source: "deb [arch=amd64 signed-by=$KEY_FILE] https://download.docker.com/linux/ubuntu $RELEASE stable"
      keyid: 9DC858229FC7DD38854AE2D88D81803C0EBFCD88

# Installation des packages
packages:
  - bridge-utils
  - jq
  - tcpdump
  - curl
  - git
  - golang
  - docker-ce
  - docker-ce-cli
  - nginx
  - net-tools
  - tshark

users:
  - name: root
    lock-passwd: false
    plain_text_passwd: '${root_password}'

ssh_pwauth: true

runcmd:
  - echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
  - echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
  - systemctl restart ssh
  - systemctl enable docker
  - systemctl start docker
  # Installation de Krew pour kubectl.
  - |
    set -eu
    krew_root=/root/.krew

    if [ ! -x "$krew_root/bin/kubectl-krew" ]; then
      tmpdir="$(mktemp -d)"
      trap 'rm -rf "$tmpdir"' EXIT
      cd "$tmpdir"

      OS="$(uname | tr '[:upper:]' '[:lower:]')"
      ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/arm.*$/arm/' -e 's/aarch64$/arm64/')"
      KREW="krew-$OS"_"$ARCH"
      curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/$KREW.tar.gz"
      tar zxvf "$KREW.tar.gz"
      ./$KREW install krew
    fi

    cat > /etc/profile.d/krew.sh <<'EOF'
    export KREW_ROOT=/root/.krew
    export PATH="/root/.krew/bin:$PATH"
    EOF
    chmod 0644 /etc/profile.d/krew.sh
    grep -qxF 'export PATH="/root/.krew/bin:$PATH"' /root/.bashrc || \
      echo 'export PATH="/root/.krew/bin:$PATH"' >> /root/.bashrc
  - git clone -q ${ghrepo} /home/cilium_lab
  - cd /home/cilium_lab/basic && bash ./00-build-foundation.sh

# Message de fin
final_message: "Lab prêt après $UPTIME secondes."
