# bazzite-deck-lab

A custom [Universal Blue](https://universal-blue.org/) image for **legion** (Lenovo Legion Go 2):
gaming-first `ghcr.io/ublue-os/bazzite-deck:stable` (KDE + Steam Gaming Mode), plus what it
needs to be a [Coolify](https://coolify.io) server.

Built from [ublue-os/image-template](https://github.com/ublue-os/image-template).

## What's added on top of bazzite-deck

| Change | Why |
| --- | --- |
| Docker CE (`docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`), `docker.service` enabled | Coolify deploys with Docker. Baked into the image instead of layered with rpm-ostree. The Docker repo file ships disabled. |
| `/data` → `/var/data` symlink, `/var/data` created at boot (`/usr/lib/tmpfiles.d/data.conf`) | The root filesystem is read-only; Coolify needs a writable `/data/coolify`. Same pattern as `/home` → `/var/home`. |
| Signing key + `policy.json` entry for `ghcr.io/ton3s/bazzite-deck-lab` | So the host can verify updates with the `ostree-image-signed:` transport. |

Nothing else changes: no firewall, SELinux, or auto-update settings are touched.

## Image

```
ghcr.io/ton3s/bazzite-deck-lab:stable
```

Signed with cosign; the public key is [`cosign.pub`](cosign.pub).

```bash
cosign verify --key cosign.pub ghcr.io/ton3s/bazzite-deck-lab:stable
```

## When it rebuilds

- On every push to `main` (and on demand from the Actions tab).
- When upstream `bazzite-deck:stable` changes: [`check-upstream.yml`](.github/workflows/check-upstream.yml)
  runs every 3 hours, compares the upstream digest with the one recorded in the published
  image's signature, and triggers a build if they differ.
- Weekly, to pick up Docker CE updates.

The build pins `FROM` to the exact upstream digest it resolved and records it as a signed
annotation (`org.ton3s.base-digest`) on the cosign signature; rechunking drops image labels,
so it can't live there:

```bash
cosign verify --key cosign.pub ghcr.io/ton3s/bazzite-deck-lab:stable \
  | jq -r '.[0].optional["org.ton3s.base-digest"]'
```

> GitHub pauses scheduled workflows in repos with no activity for 60 days. If rebuilds stop,
> re-enable the workflows from the Actions tab.

## Switching a machine to this image

First switch (the host doesn't have this image's signing key yet):

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/ton3s/bazzite-deck-lab:stable
systemctl reboot
```

Then switch to the signed transport (the key now ships in the image):

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ton3s/bazzite-deck-lab:stable
systemctl reboot
```

Roll back to the previous deployment at any time with `rpm-ostree rollback` (or pick it in the boot menu).

Updates are **not** automatic on legion; run `rpm-ostree upgrade` when you want one.
