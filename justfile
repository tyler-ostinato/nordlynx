# nordlynx app — local dev recipes
# Usage: just <recipe>
# Run from ~/development/nordlynx/

cluster       := env("CLUSTER", "kind")
registry_port := env("REGISTRY_PORT", "5001")
namespace     := "nordlynx"

# Show available recipes
default:
    @just --list

# Build, push to local registry, and apply manifests
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
    echo "  Check status: kubectl get pods -n {{namespace}}"

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

# Stream logs from the nordlynx namespace
logs:
    kubectl logs -n "{{namespace}}" --context "kind-{{cluster}}" \
        --all-containers --prefix --follow \
        -l app=nordlynx

# Delete all nordlynx resources from the cluster
teardown:
    kubectl delete -f k8s/ --context "kind-{{cluster}}" --ignore-not-found
    echo "✓ nordlynx removed from cluster."
