FROM ubuntu:24.04 AS os

LABEL maintainer="sawang-runner"
LABEL description="Multi-runner container for GitHub Actions with PM2 Process Manager"

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/home/runner
ENV PM2_HOME=/home/runner/.pm2
ENV RUNNER_ALLOW_RUNASROOT=1

# 1. Install dependensi dasar Linux & runtime libraries yang dibutuhkan GitHub Actions Runner
RUN apt-get update && apt-get install -y --no-install-recommends \
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
    && rm -rf /var/lib/apt/lists/*

# 2. Install Node.js LTS (v22) dan PM2 secara global
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g pm2 \
    && rm -rf /var/lib/apt/lists/*

# 3. Install Docker CLI & Docker Compose plugin (untuk kebutuhan CI/CD job yang menjalankan docker)
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# 4. Buat user 'runner' dengan akses sudo tanpa password & grup docker
RUN useradd -m -s /bin/bash runner \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && groupadd -f docker \
    && usermod -aG docker runner

# 5. Siapkan struktur direktori di dalam container
RUN mkdir -p /home/runner/runners \
             /home/runner/cache \
             /home/runner/.pm2 \
    && chown -R runner:runner /home/runner

WORKDIR /home/runner

# 6. Salin script operasional runner
COPY --chown=runner:runner entrypoint.sh /home/runner/entrypoint.sh
COPY --chown=runner:runner github-init.sh /home/runner/github-init.sh
COPY --chown=runner:runner github-remove.sh /home/runner/github-remove.sh
COPY --chown=runner:runner runner-list.sh /home/runner/runner-list.sh

RUN chmod +x /home/runner/*.sh

# Default user adalah 'runner' (dapat dioverride jika user ingin memakai root)
USER runner

ENTRYPOINT ["/home/runner/entrypoint.sh"]
