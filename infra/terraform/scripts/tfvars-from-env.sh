#!/usr/bin/env bash
# Génère terraform.tfvars à partir de infra/alfresco/.env.
#
# Les secrets (mots de passe PostgreSQL, ActiveMQ, secret de transformation,
# compte admin Alfresco) sont lus une seule fois et écrits dans un fichier
# git-ignoré. Ne jamais commiter terraform.tfvars.
#
# Usage :
#   ./scripts/tfvars-from-env.sh              # écrit ./terraform.tfvars
#   ./scripts/tfvars-from-env.sh --print       # affiche sans écrire
#
# Pour un cluster réel, remplacez les valeurs de development par les
# vôtres : ce fichier est un point de départ, pas une source de vérité.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$(dirname "${SCRIPT_DIR}")"
ENV_FILE="${TF_DIR}/../alfresco/.env"
OUTPUT="${TF_DIR}/terraform.tfvars"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Erreur : ${ENV_FILE} est introuvable." >&2
  echo "Copiez infra/alfresco/.env.example vers infra/alfresco/.env." >&2
  exit 1
fi

# Lit la PREMIERE occurrence de chaque clé. Le fichier .env redéclare
# ALFRESCO_PUBLIC_HOST et ALFRESCO_PROTOCOL dans la section du tunnel
# Cloudflare : la première valeur est celle du profil local, qui est celle
# que la stack Docker Compose utilise.
env_value() {
  local key="$1"
  grep -E "^${key}=" "${ENV_FILE}" | head -n 1 | cut -d= -f2-
}

require_value() {
  local key="$1"
  local value="$2"
  if [[ -z "${value}" ]]; then
    echo "Erreur : ${key} est absent ou vide dans ${ENV_FILE}." >&2
    exit 1
  fi
}

DB_USER="$(env_value DB_USER)"
DB_NAME="$(env_value DB_NAME)"
DB_PASSWORD="$(env_value DB_PASSWORD)"
ACTIVEMQ_USER="$(env_value ACTIVEMQ_USER)"
ACTIVEMQ_PASSWORD="$(env_value ACTIVEMQ_PASSWORD)"
TRANSFORM_SHARED_SECRET="$(env_value TRANSFORM_SHARED_SECRET)"
ALFRESCO_ADMIN_USER="$(env_value ALFRESCO_ADMIN_USER)"
ALFRESCO_ADMIN_PASSWORD="$(env_value ALFRESCO_ADMIN_PASSWORD)"
PUBLIC_HOST="$(env_value ALFRESCO_PUBLIC_HOST)"

require_value DB_USER "${DB_USER}"
require_value DB_NAME "${DB_NAME}"
require_value DB_PASSWORD "${DB_PASSWORD}"
require_value ACTIVEMQ_USER "${ACTIVEMQ_USER}"
require_value ACTIVEMQ_PASSWORD "${ACTIVEMQ_PASSWORD}"
require_value TRANSFORM_SHARED_SECRET "${TRANSFORM_SHARED_SECRET}"
require_value ALFRESCO_ADMIN_USER "${ALFRESCO_ADMIN_USER}"
require_value ALFRESCO_ADMIN_PASSWORD "${ALFRESCO_ADMIN_PASSWORD}"
require_value ALFRESCO_PUBLIC_HOST "${PUBLIC_HOST}"

emit() {
  # L'alignement des "=" suit terraform fmt : le fichier généré est donc
  # déjà formaté, et le régénérer ne crée pas de diff.
  cat <<EOF
# Généré par scripts/tfvars-from-env.sh — ne pas commiter.
# Source : infra/alfresco/.env

namespace   = "alfresco"
public_host = "${PUBLIC_HOST}"

db_name     = "${DB_NAME}"
db_user     = "${DB_USER}"
db_password = "${DB_PASSWORD}"

activemq_user     = "${ACTIVEMQ_USER}"
activemq_password = "${ACTIVEMQ_PASSWORD}"

transform_shared_secret = "${TRANSFORM_SHARED_SECRET}"

alfresco_admin_user     = "${ALFRESCO_ADMIN_USER}"
alfresco_admin_password = "${ALFRESCO_ADMIN_PASSWORD}"
EOF
}

if [[ "${1:-}" == "--print" ]]; then
  emit
  exit 0
fi

emit > "${OUTPUT}"
chmod 600 "${OUTPUT}"
echo "Écrit : ${OUTPUT}"
echo "Ce fichier contient des mots de passe — il est ignoré par git."
