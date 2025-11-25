#!/bin/bash
#
# Bootstrap script for Buildkite benchmark agents
# This script runs when new Buildkite agent instances are launched
# It sets up the environment for running Arrow benchmarks

set -euo pipefail

echo "==> Starting Buildkite benchmark agent bootstrap"

# Set NOPASSWD for buildkite-agent user
echo "buildkite-agent ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers

# Update system packages
echo "==> Updating system packages"
sudo yum update -y -q

# Install Arrow C++ Dependencies
echo "==> Installing Arrow C++ dependencies"
sudo yum install -y -q \
    autoconf \
    ca-certificates \
    cmake \
    g++ \
    gcc \
    gdb \
    git \
    make \
    ninja-build \
    pkg-config \
    protobuf-compiler \
    tzdata \
    wget \
    curl \
    tar \
    bzip2

# Install Arrow Python Dependencies
echo "==> Installing Python dependencies"
sudo yum install -y -q \
    python3 \
    python3-pip \
    python3-devel

# Install Docker (if not already installed)
if ! command -v docker &> /dev/null; then
    echo "==> Installing Docker"
    sudo yum install -y docker
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker buildkite-agent
fi

# Install Conda
echo "==> Installing Miniconda"
case $(uname -m) in
  aarch64)
    conda_installer=Miniconda3-latest-Linux-aarch64.sh;;
  *)
    conda_installer=Miniconda3-latest-Linux-x86_64.sh;;
esac

cd /tmp
curl -LO "https://repo.anaconda.com/miniconda/$conda_installer"
sudo -u buildkite-agent bash "$conda_installer" -b -p "/var/lib/buildkite-agent/miniconda3"
sudo -u buildkite-agent /var/lib/buildkite-agent/miniconda3/bin/conda init bash

# Set up environment file from S3 (if exists)
# The environment file should be uploaded to S3 beforehand with benchmark credentials
QUEUE_NAME="${BUILDKITE_QUEUE:-unknown}"
if [ "$QUEUE_NAME" != "unknown" ]; then
    echo "==> Attempting to download environment file for queue: $QUEUE_NAME"

    # Try to download from S3 secrets bucket
    SECRET_PATH="s3://conbench-prod-buildkite-secrets/queues/$QUEUE_NAME/env"
    if aws s3 cp "$SECRET_PATH" /var/lib/buildkite-agent/.env 2>/dev/null; then
        echo "==> Environment file downloaded successfully"
        sudo chown buildkite-agent:buildkite-agent /var/lib/buildkite-agent/.env
        sudo chmod 600 /var/lib/buildkite-agent/.env

        # Source it in buildkite-agent's bashrc
        echo "source ~/.env" | sudo tee -a /var/lib/buildkite-agent/.bashrc
    else
        echo "==> No environment file found at $SECRET_PATH (this is optional)"
    fi
fi

# Install common Python packages for benchmarking
echo "==> Installing common Python packages"
sudo -u buildkite-agent /var/lib/buildkite-agent/miniconda3/bin/pip install \
    numpy \
    pandas \
    pyarrow \
    requests

# Set up git configuration
echo "==> Configuring git"
sudo -u buildkite-agent git config --global user.name "Buildkite Agent"
sudo -u buildkite-agent git config --global user.email "buildkite@arrow-dev.org"

# Increase file limits for benchmark workloads
echo "==> Configuring system limits"
cat <<EOF | sudo tee -a /etc/security/limits.conf
buildkite-agent soft nofile 65536
buildkite-agent hard nofile 65536
buildkite-agent soft nproc 32768
buildkite-agent hard nproc 32768
EOF

# Configure sysctl for better networking performance
cat <<EOF | sudo tee -a /etc/sysctl.conf
net.core.somaxconn = 1024
net.ipv4.tcp_max_syn_backlog = 2048
EOF
sudo sysctl -p

echo "==> Bootstrap complete!"
echo "==> System info:"
echo "    Architecture: $(uname -m)"
echo "    OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2)"
echo "    Python: $(python3 --version)"
echo "    Conda: $(/var/lib/buildkite-agent/miniconda3/bin/conda --version)"
echo "    Git: $(git --version)"
