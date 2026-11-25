#!/bin/bash

set -ouex pipefail

IMAGE_REF="ghcr.io/ton3s/bazzite-deck-lab"

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Docker CE
# Add Docker's official Fedora repo, install the engine + plugins, then disable
# the repo so it is inert on the booted system (nothing gets layered from it).
dnf5 config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
dnf5 install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/docker-ce.repo

# The RPM adds the docker group to the image's /etc/group, but a host that is
# switched or upgraded keeps its own (locally modified) /etc/group, so the group
# never reaches it and docker.socket (SocketGroup=docker) fails with
# "Unknown group". Declare it for systemd-sysusers, which creates it in the
# host's /etc/group at boot if missing (free GID picked to avoid clashes).
echo "g docker -" > /usr/lib/sysusers.d/docker.conf

systemctl enable docker.service

### /data -> /var/data
# Same pattern as /home -> /var/home: the root filesystem is read-only, so
# /data points into the writable /var. /var/data itself is created at boot by
# /usr/lib/tmpfiles.d/data.conf (shipped in system_files).
rm -rf /data
ln -s var/data /data

### Signature verification for this image
# Lets the host verify updates with `ostree-image-signed:` transport.
install -Dm0644 /ctx/cosign.pub /etc/pki/containers/bazzite-deck-lab.pub
jq --arg ref "${IMAGE_REF}" \
    '.transports.docker[$ref] = [{
        "type": "sigstoreSigned",
        "keyPath": "/etc/pki/containers/bazzite-deck-lab.pub",
        "signedIdentity": {"type": "matchRepository"}
    }]' /etc/containers/policy.json > /tmp/policy.json
install -m0644 /tmp/policy.json /etc/containers/policy.json

# Sanity checks
test -L /data
test "$(readlink /data)" = "var/data"
rpm -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
jq -e --arg ref "${IMAGE_REF}" '.transports.docker[$ref]' /etc/containers/policy.json
