FROM ubuntu:26.04 AS os

LABEL maintainer="sawang-runner"
LABEL description="Multi-runner container for GitHub Actions with PM2 Process Manager"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV HOME=/home/runner
ENV PM2_HOME=/home/runner/.pm2
ENV RUNNER_ALLOW_RUNASROOT=1

# 1. Install dependensi dasar Linux, locales (UTF-8 untuk btop), dan runtime libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales \
    ca-certificates \
    htop \
    btop \
    curl \
    wget \
    git \
    jq \
    tar \
    gzip \
    unzip \
    zip \
    sudo \
    gnupg \
    lsb-release \
    iputils-ping \
    build-essential \
    libicu-dev \
    libssl-dev \
    libkrb5-3 \
    zlib1g \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && printf '#!/bin/sh\nexport LANG="${LANG:-en_US.UTF-8}"\nexport LC_ALL="${LC_ALL:-en_US.UTF-8}"\nexec /usr/bin/btop --force-utf "$@"\n' > /usr/local/bin/btop \
    && chmod +x /usr/local/bin/btop \
    && rm -rf /var/lib/apt/lists/*

# 2. Install Node.js LTS (v22) dan PM2 secara global
RUN apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    npm \
    && npm install -g pm2 \
    && rm -rf /var/lib/apt/lists/*

# 3. Install Docker CLI & Docker Buildx
RUN apt-get update && apt-get install -y --no-install-recommends \
    docker.io \
    docker-buildx \
    && rm -rf /var/lib/apt/lists/*

# 4. Install GitLab Runner & Gitea Actions Runner (act_runner) binaries
RUN ARCH=$(dpkg --print-architecture) \
    && echo "Mengunduh gitlab-runner untuk arsitektur ${ARCH}..." \
    && curl -fsSL -o /usr/local/bin/gitlab-runner "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-${ARCH}" \
    && chmod +x /usr/local/bin/gitlab-runner \
    && echo "Mengunduh gitea-runner untuk arsitektur ${ARCH}..." \
    && curl -fsSL -o /usr/local/bin/gitea-runner "https://gitea.com/gitea/runner/releases/download/v5.1.0/gitea-runner-5.1.0-linux-${ARCH}" \
    && chmod +x /usr/local/bin/gitea-runner \
    && ln -sf /usr/local/bin/gitea-runner /usr/local/bin/act_runner

# 5. Buat user 'runner' dengan akses sudo tanpa password & grup docker
RUN useradd -m -s /bin/bash runner \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && groupadd -f docker \
    && usermod -aG docker runner \
    && echo 'export LANG=en_US.UTF-8' >> /home/runner/.bashrc \
    && echo 'export LC_ALL=en_US.UTF-8' >> /home/runner/.bashrc

# 6. Siapkan struktur direktori di dalam container
RUN mkdir -p /home/runner/runners \
             /home/runner/cache \
             /home/runner/.pm2 \
    && chown -R runner:runner /home/runner

WORKDIR /home/runner

# 7. Salin script operasional runner (GitHub, GitLab, Gitea)
COPY --chown=runner:runner entrypoint.sh /home/runner/entrypoint.sh
COPY --chown=runner:runner runner-list.sh /home/runner/runner-list.sh
COPY --chown=runner:runner github-init.sh /home/runner/github-init.sh
COPY --chown=runner:runner github-remove.sh /home/runner/github-remove.sh
COPY --chown=runner:runner gitlab-init.sh /home/runner/gitlab-init.sh
COPY --chown=runner:runner gitlab-remove.sh /home/runner/gitlab-remove.sh
COPY --chown=runner:runner gitea-init.sh /home/runner/gitea-init.sh
COPY --chown=runner:runner gitea-remove.sh /home/runner/gitea-remove.sh

RUN chmod +x /home/runner/*.sh

USER runner

ENTRYPOINT ["/home/runner/entrypoint.sh"]
