# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files
COPY cosign.pub /cosign.pub

# Base Image
# The Justfile resolves ghcr.io/ublue-os/bazzite-deck:stable to an exact digest
# and passes it in as BASE_IMAGE, so every build records exactly which upstream
# image it was built from (see the org.ton3s.base-digest label).
ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite-deck:stable
FROM ${BASE_IMAGE}

### MODIFICATIONS
## Docker CE, the /data -> /var/data symlink, and signing policy are set up in build.sh

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
