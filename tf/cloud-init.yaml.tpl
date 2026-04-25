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

users:
  - name: root
    lock-passwd: false
    plain_text_passwd: '${root_password}'
ssh_pwauth: true

runcmd:
  - sed -i -e '/^PermitRootLogin/s/^.*$/PermitRootLogin yes/' /etc/ssh/sshd_config
  - sed -i -e '/^PasswordAuthentication/s/^.*$/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - systemctl restart ssh
  - systemctl enable docker
  - systemctl start docker
  - git clone ${ghrepo} /home/cilium_lab

# Message de fin
final_message: "Lab prêt après $UPTIME secondes."
