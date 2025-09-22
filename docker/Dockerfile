# Dockerfile for Jules Endpoint Agent
# This Dockerfile creates a standardized, isolated Linux environment for running the agent.

# Use a stable base image
FROM ubuntu:22.04

# Set non-interactive frontend for package installs
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
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

# Configure SSH server
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    mkdir /run/sshd

# Create the entrypoint script
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -e' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo 'if [ -z "$JULES_SSH_PUBLIC_KEY" ]; then' >> /entrypoint.sh && \
    echo '  echo "ERROR: The JULES_SSH_PUBLIC_KEY environment variable must be set." >&2' >> /entrypoint.sh && \
    echo '  exit 1' >> /entrypoint.sh && \
    echo 'fi' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# Create a non-root user for the agent' >> /entrypoint.sh && \
    echo 'useradd -m -s /bin/bash jules' >> /entrypoint.sh && \
    echo 'echo "jules ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# Set up SSH for the new user' >> /entrypoint.sh && \
    echo 'mkdir -p /home/jules/.ssh' >> /entrypoint.sh && \
    echo 'echo "$JULES_SSH_PUBLIC_KEY" > /home/jules/.ssh/authorized_keys' >> /entrypoint.sh && \
    echo 'chown -R jules:jules /home/jules/.ssh' >> /entrypoint.sh && \
    echo 'chmod 700 /home/jules/.ssh' >> /entrypoint.sh && \
    echo 'chmod 600 /home/jules/.ssh/authorized_keys' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# Start cloudflared tunnel in the background' >> /entrypoint.sh && \
    echo 'echo "[AGENT] Starting cloudflared tunnel for SSH..."' >> /entrypoint.sh && \
    echo 'cloudflared tunnel --no-autoupdate --url ssh://localhost:22 run --token ${CLOUDFLARE_TOKEN} &>/dev/null &' >> /entrypoint.sh && \
    echo '' >> /entrypoint.sh && \
    echo '# Start SSH server in the foreground' >> /entrypoint.sh && \
    echo 'echo "[AGENT] Starting SSH server..."' >> /entrypoint.sh && \
    echo '/usr/sbin/sshd -D' >> /entrypoint.sh

RUN chmod +x /entrypoint.sh

# Expose the SSH port
EXPOSE 22

# Run the entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
