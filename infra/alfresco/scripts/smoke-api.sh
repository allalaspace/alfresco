#!/usr/bin/env bash
# Scénario API REST v1 : identité, site, upload, lecture, téléchargement, recherche.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Valeurs fournies par l'appelant : elles priment sur le .env, pour pouvoir
# cibler un autre port que celui du Compose (par exemple le NodePort
# 30080 de la stack Terraform sur Kubernetes).
declare -A OVERRIDES=()
for key in ALFRESCO_PORT SHARE_PORT ALFRESCO_ADMIN_USER ALFRESCO_ADMIN_PASSWORD ALFRESCO_SITE_ID; do
  if [[ -n "${!key:-}" ]]; then
    OVERRIDES["${key}"]="${!key}"
  fi
done

if [[ -f "${ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT}/.env"
  set +a
fi

for key in "${!OVERRIDES[@]}"; do
  export "${key}=${OVERRIDES[${key}]}"
done

# Appels locaux. Le nom public du tunnel ne remplace pas le port publié sur la machine.
HOST="127.0.0.1"
PORT="${ALFRESCO_PORT:-8080}"
USER_NAME="${ALFRESCO_ADMIN_USER:-admin}"
PASSWORD="${ALFRESCO_ADMIN_PASSWORD:-admin}"
SITE_ID="${ALFRESCO_SITE_ID:-poc-api}"
BASE="http://${HOST}:${PORT}/alfresco/api/-default-/public/alfresco/versions/1"
SEARCH="http://${HOST}:${PORT}/alfresco/api/-default-/public/search/versions/1/search"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

# Sur Windows, "python3" pointe souvent vers le stub du Microsoft Store.
# On cherche un interpréteur qui fonctionne vraiment.
PYTHON=""
for candidate in python3 python py; do
  if command -v "${candidate}" >/dev/null 2>&1 && "${candidate}" -c 'import json' >/dev/null 2>&1; then
    PYTHON="${candidate}"
    break
  fi
done
if [[ -z "${PYTHON}" ]]; then
  echo "Erreur : aucun interpréteur Python utilisable trouvé (python3, python, py)." >&2
  exit 1
fi

api() {
  curl -fsS -u "${USER_NAME}:${PASSWORD}" "$@"
}

echo "1. Identité"
api "${BASE}/people/-me-" | tee "${WORKDIR}/me.json" >/dev/null
"${PYTHON}" - "${WORKDIR}/me.json" <<'PY'
import json, sys
entry = json.load(open(sys.argv[1]))["entry"]
print(f"   connecté en tant que {entry['id']}")
PY

echo "2. Site ${SITE_ID}"
status="$(curl -sS -o "${WORKDIR}/site.json" -w "%{http_code}" \
  -u "${USER_NAME}:${PASSWORD}" \
  -H "Content-Type: application/json" \
  -d "{\"id\":\"${SITE_ID}\",\"title\":\"POC API\",\"description\":\"Site local pour l'appel API\",\"visibility\":\"PRIVATE\"}" \
  "${BASE}/sites")"
case "${status}" in
  201) echo "   site créé" ;;
  409) echo "   site déjà présent" ;;
  *)
    echo "   échec création site (HTTP ${status})" >&2
    cat "${WORKDIR}/site.json" >&2
    exit 1
    ;;
esac

echo "3. Bibliothèque documentaire"
api "${BASE}/sites/${SITE_ID}/containers" > "${WORKDIR}/containers.json"
FOLDER_ID="$("${PYTHON}" - "${WORKDIR}/containers.json" <<'PY'
import json, sys
entries = json.load(open(sys.argv[1]))["list"]["entries"]
for item in entries:
    entry = item["entry"]
    # ACS 7.x : id = nom du conteneur, folderId = nœud.
    # ACS 26.2 : id = nœud, folderId = nom du conteneur.
    if entry.get("id") == "documentLibrary":
        print(entry["folderId"])
        break
    if entry.get("folderId") == "documentLibrary":
        print(entry["id"])
        break
else:
    sys.exit("documentLibrary introuvable")
PY
)"
echo "   folderId=${FOLDER_ID}"

echo "4. Upload"
SAMPLE="${WORKDIR}/exemple.txt"
printf 'Document de test Alfresco — %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${SAMPLE}"
# Le nom du fichier envoyé est déjà celui du fichier source, la forme
# ";"filename=" n'est donc pas nécessaire. Elle échoue en plus avec le
# curl natif de Windows (mingw), qui ne lit plus le fichier local.
api \
  -F "filedata=@${SAMPLE}" \
  -F "name=exemple.txt" \
  -F "nodeType=cm:content" \
  -F "autoRename=true" \
  "${BASE}/nodes/${FOLDER_ID}/children" > "${WORKDIR}/upload.json"
NODE_ID="$("${PYTHON}" - "${WORKDIR}/upload.json" <<'PY'
import json, sys
entry = json.load(open(sys.argv[1]))["entry"]
print(entry["id"])
print(entry["name"], file=sys.stderr)
PY
)"
echo "   nodeId=${NODE_ID}"

echo "5. Métadonnées"
api "${BASE}/nodes/${NODE_ID}" | "${PYTHON}" -c 'import json,sys; e=json.load(sys.stdin)["entry"]; c=e["content"]; print("   %s (%s, %s octets)" % (e["name"], c["mimeType"], c["sizeInBytes"]))'

echo "6. Téléchargement"
api -o "${WORKDIR}/download.txt" "${BASE}/nodes/${NODE_ID}/content"
cmp -s "${SAMPLE}" "${WORKDIR}/download.txt"
echo "   contenu identique au fichier envoyé"

echo "7. Recherche (indexation asynchrone, quelques secondes)"
found=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  api -H "Content-Type: application/json" \
    -d "{\"query\":{\"query\":\"ID:${NODE_ID}\",\"language\":\"afts\"},\"paging\":{\"maxItems\":5}}" \
    "${SEARCH}" > "${WORKDIR}/search.json"
  found="$("${PYTHON}" - "${WORKDIR}/search.json" "${NODE_ID}" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
wanted = sys.argv[2]
entries = payload.get("list", {}).get("entries", [])
print(1 if any(item["entry"]["id"] == wanted for item in entries) else 0)
PY
)"
  if [[ "${found}" == "1" ]]; then
    break
  fi
  sleep 10
done

if [[ "${found}" == "1" ]]; then
  echo "   document retrouvé par la Search API"
else
  echo "   document pas encore indexé (batch-indexing). Réessayer dans une minute." >&2
  exit 1
fi

echo "Appel API terminé."
echo "Share : http://${HOST}:${SHARE_PORT:-8081}/share"
echo "API   : ${BASE}"
