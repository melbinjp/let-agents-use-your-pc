# Dockerfile for Jules Endpoint Agent
# This Dockerfile creates a standardized, isolated Linux environment for running the agent.

# Use a stable base image
FROM ubuntu:22.04

# Set non-interactive frontend for package installs
ENV DEBIAN_FRONTEND=noninteractive

# Install basic dependencies and development tools
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    tree \
    unzip \
    build-essential \
    python3 \
    python3-pip \
    nodejs \
    npm \
    openssl \
    ca-certificates \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Install openssh-server and sudo
RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Install cloudflared
RUN curl -sL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# Configure SSH server with enhanced security settings
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config && \
    sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#UsePAM yes/UsePAM yes/' /etc/ssh/sshd_config && \
    echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config && \
    echo "ClientAliveCountMax 3" >> /etc/ssh/sshd_config && \
    mkdir -p /run/sshd

# Create the entrypoint, health check, and connection info scripts
COPY docker/entrypoint.sh /entrypoint.sh
COPY docker/healthcheck.sh /healthcheck.sh
COPY docker/connection-info.sh /app/connection-info.sh
COPY docker/hardware-detection.sh /app/hardware-detection.sh
COPY docker/performance-optimization.sh /app/performance-optimization.sh

# Copy security modules
COPY linux/ssh-key-validator.sh /app/ssh-key-validator.sh
COPY linux/ssh-security-hardening.sh /app/ssh-security-hardening.sh

# Copy diagnostics modules
COPY diagnostics/ /app/diagnostics/
COPY diagnose.sh /app/diagnose.sh

# Install additional diagnostic dependencies and hardware tools
RUN apt-get update && apt-get install -y \
    bc \
    net-tools \
    pciutils \
    usbutils \
    lshw \
    hwinfo \
    dmidecode \
    util-linux \
    smartmontools \
    hdparm \
    iotop \
    sysstat \
    stress-ng \
    memtester \
    cpufrequtils \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Install NVIDIA Container Toolkit components (if available)
RUN apt-get update && apt-get install -y \
    nvidia-container-toolkit-base \
    libnvidia-container-tools \
    --no-install-recommends || true && \
    rm -rf /var/lib/apt/lists/*

RUN chmod +x /entrypoint.sh /healthcheck.sh /app/connection-info.sh /app/ssh-key-validator.sh /app/ssh-security-hardening.sh /app/diagnose.sh /app/diagnostics/*.sh /app/hardware-detection.sh /app/performance-optimization.sh

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /healthcheck.sh

# Expose the SSH port
EXPOSE 22

# Run the entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
