#!/usr/bin/env bash
set -euo pipefail

# ── Config ────────────────────────────────────────────────────
NAMESPACE="todo"
SERVICE="todo-api"
IMAGE="${1:-dogukanc760/todo-api:latest}"
REPLICAS=2
HEALTH_RETRIES=20
HEALTH_INTERVAL=5

# ── Aktif versiyonu tespit et ─────────────────────────────────
ACTIVE=$(kubectl get service "$SERVICE" -n "$NAMESPACE" \
  -o jsonpath='{.spec.selector.version}')

if [[ "$ACTIVE" == "blue" ]]; then
  NEXT="green"
else
  NEXT="blue"
fi

echo "► Active: $ACTIVE | Deploying to: $NEXT"
echo "► Image: $IMAGE"

# ── Yeni image'ı set et ve scale up yap ──────────────────────
kubectl set image deployment/todo-api-"$NEXT" \
  todo-api="$IMAGE" -n "$NAMESPACE"

kubectl scale deployment/todo-api-"$NEXT" \
  --replicas="$REPLICAS" -n "$NAMESPACE"

echo "► Waiting for $NEXT deployment to be ready..."

# ── Rollout tamamlanana kadar bekle ──────────────────────────
if ! kubectl rollout status deployment/todo-api-"$NEXT" \
  -n "$NAMESPACE" --timeout=120s; then
  echo "✗ Rollout failed. Rolling back..."
  kubectl scale deployment/todo-api-"$NEXT" --replicas=0 -n "$NAMESPACE"
  exit 1
fi

# ── Health check ─────────────────────────────────────────────
echo "► Running health checks..."
RETRIES=0
until kubectl exec -n "$NAMESPACE" \
  "$(kubectl get pod -n "$NAMESPACE" -l app=todo-api,version="$NEXT" \
    -o jsonpath='{.items[0].metadata.name}')" \
  -- wget -qO- http://localhost:3000/health | grep -q '"status":"ok"'; do

  RETRIES=$((RETRIES + 1))
  if [[ $RETRIES -ge $HEALTH_RETRIES ]]; then
    echo "✗ Health check failed after $RETRIES retries. Rolling back..."
    kubectl scale deployment/todo-api-"$NEXT" --replicas=0 -n "$NAMESPACE"
    exit 1
  fi
  echo "  Health check attempt $RETRIES/$HEALTH_RETRIES — retrying in ${HEALTH_INTERVAL}s..."
  sleep "$HEALTH_INTERVAL"
done

echo "✓ Health check passed"

# ── Traffic switch ────────────────────────────────────────────
echo "► Switching traffic: $ACTIVE → $NEXT"
kubectl patch service "$SERVICE" -n "$NAMESPACE" \
  -p "{\"spec\":{\"selector\":{\"app\":\"todo-api\",\"version\":\"$NEXT\"}}}"

kubectl annotate service "$SERVICE" -n "$NAMESPACE" \
  active-version="$NEXT" --overwrite

# ── Eski deployment scale down ───────────────────────────────
echo "► Scaling down $ACTIVE..."
kubectl scale deployment/todo-api-"$ACTIVE" \
  --replicas=0 -n "$NAMESPACE"

echo ""
echo "✓ Blue-green switch complete: $ACTIVE → $NEXT"
echo "  Image: $IMAGE"
