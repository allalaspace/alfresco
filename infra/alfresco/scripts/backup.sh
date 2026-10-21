#!/usr/bin/env bash
# Sauvegarde la base PostgreSQL et le contenu Alfresco (volume alfresco_data).
# Elasticsearch se reconstruit via batch-indexing ; il n'est pas inclus.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
DEST="${ROOT}/backups/${STAMP}"
mkdir -p "${DEST}"

docker compose exec -T postgres \
  pg_dump -U "${DB_USER:-alfresco}" -d "${DB_NAME:-alfresco}" --clean --if-exists \
  > "${DEST}/postgres.sql"

CID="$(docker compose ps -q alfresco)"
if [[ -z "${CID}" ]]; then
  echo "Le conteneur alfresco n'est pas démarré." >&2
  exit 1
fi

docker run --rm --volumes-from "${CID}" -v "${DEST}:/backup" alpine:3.22 \
  tar czf /backup/alfresco-content.tgz -C /usr/local/tomcat/alf_data .

echo "Sauvegarde écrite dans ${DEST}"
