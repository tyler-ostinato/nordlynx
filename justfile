# nordlynx — local dev recipes
# Usage: just <recipe>
# Run from ~/development/nordlynx/
#
# NOTE: nordlynx, microsocks, and qbittorrent all run in the same pod.
# 'just deploy' here rebuilds the nordlynx image and applies all manifests.
# To rebuild only the qbittorrent image, use 'just deploy' from ~/development/qbittorrent/.

cluster       := env("CLUSTER", "kind")
registry_port := env("REGISTRY_PORT", "5001")
namespace     := "nordlynx"

# Show available recipes
default:
    @just --list

# Build nordlynx image, push to local registry, and apply all manifests
deploy:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! docker ps --filter "name=kind-registry" --format "{{{{.Names}}" | grep -q "kind-registry"; then
        echo "✗ Local registry is not running. Run 'just start' from the kubernetes directory." >&2; exit 1
    fi
    echo "=> Building nordlynx image..."
    docker build -t localhost:{{registry_port}}/nordlynx:dev .
    echo "=> Pushing to local registry..."
    docker push localhost:{{registry_port}}/nordlynx:dev
    echo "=> Applying manifests..."
    kubectl apply -f k8s/ --context "kind-{{cluster}}"
    echo "✓ nordlynx deployed."

# Create/update the nordlynx Secret from .env
secret:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f ".env" ]; then
        echo "✗ .env not found. Copy .env.example and fill in your values." >&2; exit 1
    fi
    kubectl create namespace "{{namespace}}" --context "kind-{{cluster}}" 2>/dev/null || true
    kubectl create secret generic nordlynx-env \
        -n "{{namespace}}" \
        --context "kind-{{cluster}}" \
        --from-env-file=.env \
        --dry-run=client -o yaml | kubectl apply -f -
    echo "✓ nordlynx secret created/updated."

# Restart the nordlynx pod (restarts all sidecars: nordlynx, microsocks, qbittorrent)
restart:
    kubectl rollout restart deployment/nordlynx \
        -n "{{namespace}}" --context "kind-{{cluster}}"
    kubectl rollout status deployment/nordlynx \
        -n "{{namespace}}" --context "kind-{{cluster}}"
    echo "✓ nordlynx pod restarted."

# Stream logs from all containers in the nordlynx pod
logs:
    kubectl logs -n "{{namespace}}" --context "kind-{{cluster}}" \
        --all-containers --prefix --follow \
        -l app=nordlynx

# Delete all nordlynx resources from the cluster (including qbittorrent PVCs)
teardown:
    kubectl delete -f k8s/ --context "kind-{{cluster}}" --ignore-not-found
    echo "✓ nordlynx removed from cluster."
