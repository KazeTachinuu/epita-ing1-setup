# Test bench: an x86_64 Linux like the PIE (GEF needs binutils and file),
# an unprivileged user, a fake AFS cell at /afs (PAM makes ~/afs a symlink
# into it), sshd for the sshfs case.
FROM --platform=linux/amd64 debian:bookworm-slim
RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -qq --no-install-recommends bash dash busybox git curl ca-certificates \
    python3 python3-pip clang-format gdb binutils file vim-nox procps sshfs \
    fuse3 openssh-server openssh-client >/dev/null \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash student \
    && mkdir -p /run/sshd /etc/ssh/ak /afs/cri.epita.fr/user \
    && chown student /afs/cri.epita.fr/user \
    && echo 'AuthorizedKeysFile /etc/ssh/ak/%u' >> /etc/ssh/sshd_config
