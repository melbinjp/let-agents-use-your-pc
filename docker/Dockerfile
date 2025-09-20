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
    openssh-server \
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

# Install cloudflared
RUN curl -sL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# Copy the runner script into the image from the common directory
COPY common/runner.sh /usr/local/bin/runner.sh
RUN chmod +x /usr/local/bin/runner.sh

# Create the entrypoint script
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'echo "[AGENT] Starting SSH server..."' >> /entrypoint.sh && \
    echo 'service ssh start' >> /entrypoint.sh && \
    echo 'echo "[AGENT] Starting cloudflared tunnel..."' >> /entrypoint.sh && \
    echo 'if [ -n "${CLOUDFLARE_TOKEN}" ]; then' >> /entrypoint.sh && \
    echo '  echo "[AGENT] Using permanent tunnel with token."' >> /entrypoint.sh && \
    echo '  cloudflared tunnel --no-autoupdate run --token ${CLOUDFLARE_TOKEN}' >> /entrypoint.sh && \
    echo 'else' >> /entrypoint.sh && \
    echo '  echo "[AGENT] Using temporary tunnel."' >> /entrypoint.sh && \
    echo '  cloudflared tunnel --no-autoupdate --url ssh://localhost:22' >> /entrypoint.sh && \
    echo 'fi' >> /entrypoint.sh

RUN chmod +x /entrypoint.sh

# Add user and set up passwordless sudo
RUN useradd -m -s /bin/bash jules
RUN usermod -aG sudo jules
RUN echo "jules:jules" | chpasswd
RUN echo "root:root" | chpasswd
RUN echo "jules ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Expose the SSH port
EXPOSE 22

# Run the entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
