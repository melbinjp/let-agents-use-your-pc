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

# Install shell2http
RUN curl -sL "https://github.com/msoap/shell2http/releases/download/v1.17.0/shell2http_1.17.0_linux_amd64.tar.gz" | tar -xz -C /usr/local/bin

# Install cloudflared
RUN curl -sL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" -o /usr/local/bin/cloudflared && \
    chmod +x /usr/local/bin/cloudflared

# Copy the runner script into the image
COPY runner.sh /usr/local/bin/runner.sh
RUN chmod +x /usr/local/bin/runner.sh

# Create the entrypoint script
RUN echo '#!/bin/bash' > /entrypoint.sh && \
    echo 'set -m' >> /entrypoint.sh && \
    echo 'echo "[AGENT] Starting cloudflared tunnel..."' >> /entrypoint.sh && \
    echo 'cloudflared tunnel --no-autoupdate run --token ${CLOUDFLARE_TOKEN} &' >> /entrypoint.sh && \
    echo 'echo "[AGENT] Starting shell2http server..."' >> /entrypoint.sh && \
    echo 'shell2http -host 0.0.0.0 -port 8080 -form -include-stderr -500 -basic-auth "${JULES_USERNAME}:${JULES_PASSWORD}" /run "/usr/local/bin/runner.sh"' >> /entrypoint.sh && \
    echo 'fg %1' >> /entrypoint.sh

RUN chmod +x /entrypoint.sh

# Expose the port shell2http will run on
EXPOSE 8080

# Run the entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
