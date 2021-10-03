#! /bin/bash
hostnamectl set-hostname ${nodename}
# Update OS 
apt-get update -y
apt-get upgrade -y
# Install and start Docker on Ubuntu 19.03
# Update the apt package index and install packages to allow apt to use a repository over HTTPS
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release
# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
# Use the following command to set up the stable repository
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
# Update packages
apt-get update -y
# List the versions available in your repo
apt-cache madison docker-ce -y

# Since Rancher is not compatible (yet) with latest version of Docker install version 19.03.15 or earlier version using the version string (exp: 5:19.03.15~3-0~ubuntu-focal) from the second column
apt-get install docker-ce=18.06.1~ce~3-0~ubuntu containerd.io -y
systemctl start docker
systemctl enable docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu
newgrp docker
