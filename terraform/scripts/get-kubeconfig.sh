#!/usr/bin/env bash

set -e

TIMEOUT="${1:-300}"

echo "Waiting for K3s server to be ready..."

if ! timeout "$TIMEOUT" bash -c '
    until incus exec k3s-master -- k3s kubectl get nodes >/dev/null 2>&1; do
        echo "Waiting for K3s server to be ready..."
        sleep 10
    done
'; then
    echo "Error: Timeout waiting for K3s server to be ready"
    exit 1
fi

echo "K3s server is ready!"

echo "Fetching kubeconfig..."
incus file pull k3s-master/etc/rancher/k3s/k3s.yaml /tmp/kubeconfig

echo "Updating kubeconfig server address for port-forward access..."
sed -i "s/127.0.0.1:6443/localhost:6443/g" /tmp/kubeconfig

echo "Kubeconfig saved to /tmp/kubeconfig"
echo "You can now use: export KUBECONFIG=\$(pwd)/kubeconfig && kubectl get nodes"
