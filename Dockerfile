# syntax=docker/dockerfile:1.7

FROM ubuntu:24.04 AS base

ARG DEBIAN_FRONTEND=noninteractive
ARG MESA_USER=mesa
ARG MESA_UID=1000
ARG MESA_GID=1000

ENV MESA_DIR=/opt/mesa \
    MESASDK_ROOT=/opt/mesasdk \
    HDF5_USE_FILE_LOCKING=FALSE \
    BASH_ENV=/etc/profile.d/mesa.sh \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        binutils \
        ca-certificates \
        curl \
        dbus-x11 \
        fluxbox \
        git \
        libc6-dev \
        libx11-6 \
        libx11-dev \
        libxext6 \
        libxt6 \
        locales \
        make \
        novnc \
        openssh-server \
        perl \
        procps \
        python3 \
        python-is-python3 \
        sudo \
        tar \
        tcsh \
        tini \
        unzip \
        vim-tiny \
        websockify \
        wget \
        x11vnc \
        xauth \
        xterm \
        xvfb \
        xz-utils \
        zlib1g \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html \
    && mkdir -p /var/run/sshd /run/sshd \
    && ssh-keygen -A

# Ubuntu 24.04 images ship an `ubuntu` user/group at uid/gid 1000.
RUN if getent passwd ubuntu >/dev/null; then userdel -r ubuntu; fi \
    && if getent group ubuntu >/dev/null; then groupdel ubuntu; fi \
    && groupadd --gid "${MESA_GID}" "${MESA_USER}" \
    && useradd --uid "${MESA_UID}" --gid "${MESA_GID}" --create-home --shell /bin/bash "${MESA_USER}" \
    && echo "${MESA_USER} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/"${MESA_USER}" \
    && chmod 0440 /etc/sudoers.d/"${MESA_USER}" \
    && passwd -d "${MESA_USER}" \
    && install -d -m 0755 -o "${MESA_USER}" -g "${MESA_USER}" "/home/${MESA_USER}/work"

COPY docker/sshd_config /etc/ssh/sshd_config.d/mesa.conf
COPY docker/mesa.sh /etc/profile.d/mesa.sh
COPY --chmod=755 scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=755 scripts/validate-tutorial.sh /usr/local/bin/validate-tutorial.sh
COPY --chmod=755 scripts/install-mesa.sh /usr/local/sbin/install-mesa.sh

RUN echo '. /etc/profile.d/mesa.sh' >>"/home/${MESA_USER}/.bashrc" \
    && echo '. /etc/profile.d/mesa.sh' >>"/home/${MESA_USER}/.profile"

WORKDIR /home/mesa
EXPOSE 22 5901 6080
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]

FROM base AS mesa

ARG MESA_ARCHIVE=mesa-26.04.1.zip
ARG MESASDK_ARCHIVE=mesasdk-x86_64-linux-26.6.1.tar.gz

RUN --mount=type=bind,source=.tmp,target=/archives,ro \
    ARCHIVE_DIR=/archives \
    MESA_ARCHIVE="${MESA_ARCHIVE}" \
    MESASDK_ARCHIVE="${MESASDK_ARCHIVE}" \
    /usr/local/sbin/install-mesa.sh
