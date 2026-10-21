#!/usr/bin/env bash
# Attend que le repository Alfresco réponde sur la sonde ready.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "${ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT}/.env"
  set +a
fi

# Sonde locale, même si ALFRESCO_PUBLIC_HOST pointe vers le nom public du tunnel.
HOST="127.0.0.1"
PORT="${ALFRESCO_PORT:-8080}"
TIMEOUT="${WAIT_TIMEOUT_SECONDS:-600}"
URL="http://${HOST}:${PORT}/alfresco/api/-default-/public/alfresco/versions/1/probes/-ready-"

echo "Attente de ${URL} (timeout ${TIMEOUT}s)"
deadline=$((SECONDS + TIMEOUT))
until curl -fsS -o /dev/null "${URL}"; do
  if (( SECONDS >= deadline )); then
    echo "Alfresco n'est pas prêt après ${TIMEOUT}s." >&2
    echo "Voir les logs : docker compose -f ${ROOT}/docker-compose.yml logs alfresco" >&2
    exit 1
  fi
  sleep 5
done

echo "Alfresco est prêt."
