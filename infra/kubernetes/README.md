# Alfresco Community sur Kubernetes

Même stack que `infra/alfresco/docker-compose.yml` : ACS Community **26.2**, Share, PostgreSQL, Elasticsearch, batch-indexing, ActiveMQ et Transform Core.

Pour ouvrir cette machine sur Internet, le chemin prévu est le tunnel Cloudflare du Compose, pas ces NodePorts.

Les noms DNS internes reprennent les noms du Compose (`postgres`, `elasticsearch`, `activemq`, `alfresco`, `transform-core-aio`). Les Pods s’attendent via des init containers, à la place des `depends_on`.

## Composants

| Composant | Ressource | Accès |
|-----------|-----------|--------|
| **Alfresco (ACS)** | Deployment + Service NodePort `30080` | http://localhost:30080 |
| **Share** | Deployment + Service NodePort `30081` | http://localhost:30081/share |
| **PostgreSQL** | Deployment + PVC `postgres-data` | interne, port 5432 |
| **Elasticsearch** | Deployment + PVC `elasticsearch-data` | interne, port 9200 |
| **batch-indexing** | Deployment | interne |
| **ActiveMQ** | Deployment + Service `61616` | console http://localhost:30161 |
| **Transform Core** | Deployment + Service `8090` | interne |

Le contenu binaire est dans le PVC `alfresco-data`. PostgreSQL et Elasticsearch ont leur propre volume.

Versions d’images, identiques à `.env.example` :

| Image | Tag |
|-------|-----|
| `alfresco/alfresco-content-repository-community` | `26.2.0` |
| `alfresco/alfresco-share` | `26.2.2` |
| `alfresco/alfresco-transform-core-aio` | `5.4.4` |
| `postgres` | `17.9` |
| `elasticsearch` | `8.17.10` |
| `alfresco/alfresco-elasticsearch-batch-indexing` | `5.8.0` |
| `alfresco/alfresco-activemq` | `6.2.9-jre17-rockylinux8` |

## Prérequis

- `kubectl` configuré sur un cluster (Kubernetes de Docker Desktop convient)
- une StorageClass par défaut
- **au moins 8 Go de RAM** pour le cluster (12 Go recommandés)
- les NodePorts `30080`, `30081` et `30161` libres

Sur Docker Desktop, ces NodePorts répondent sur `localhost`.

## Démarrage

Depuis la racine du dépôt :

```bash
kubectl apply -k infra/kubernetes
kubectl -n alfresco get pods
```

Le premier démarrage prend plusieurs minutes (téléchargement des images, bootstrap de la base). Le dépôt est prêt quand le Pod `alfresco` est `Running` et `READY 1/1` :

```bash
kubectl -n alfresco rollout status deployment/alfresco --timeout=15m
```

| Service | URL |
|---------|-----|
| API REST v1 | http://localhost:30080/alfresco/api/-default-/public/alfresco/versions/1 |
| Share | http://localhost:30081/share |
| Console ActiveMQ | http://localhost:30161 |

Compte bootstrap : `admin` / `admin` (voir `secret.yaml`).

Sonde de démarrage :

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:30080/alfresco/api/-default-/public/alfresco/versions/1/probes/-ready-
```

Le script `infra/alfresco/scripts/smoke-api.sh` cible le port `8080` du Compose. Pour cette stack :

```bash
ALFRESCO_PORT=30080 ./infra/alfresco/scripts/smoke-api.sh
```

## Configuration

`configmap.yaml` porte l’hôte et les ports annoncés aux clients (`ALFRESCO_PUBLIC_HOST`, `ALFRESCO_PORT`, `SHARE_PORT`). Les valeurs par défaut correspondent aux NodePorts.

`secret.yaml` reprend les mots de passe de développement de `.env.example` (`alfresco` / `admin` / `secret`). Ils sont prévus pour un cluster local. Remplace-les avant tout autre usage, puis redémarre les Deployments :

```bash
kubectl -n alfresco rollout restart deployment/alfresco deployment/share deployment/postgres deployment/activemq deployment/batch-indexing
```

Les mots de passe du keystore dans `alfresco.yaml` sont ceux livrés dans l’image, comme dans le Compose. Ils doivent rester alignés avec ce keystore.

## Arrêt

Mettre les services à zéro conserve les PVC :

```bash
kubectl -n alfresco scale deployment --all --replicas=0
```

Supprimer la stack supprime aussi le namespace et les volumes (contenu et base) :

```bash
kubectl delete -k infra/kubernetes
```

## Limites

Un replica par composant, sans Ingress ni haute disponibilité. Elasticsearch est en nœud unique avec `node.store.allow_mmap=false`, pour démarrer sans modifier le sysctl du nœud. Les plafonds mémoire reprennent les `mem_limit` du Compose.
