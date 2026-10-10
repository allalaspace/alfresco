# Alfresco Community en local

Stack ACS **26.2** : repository, Share, PostgreSQL, Elasticsearch, batch-indexing, ActiveMQ, transform core.

## Composants

Le dépôt Alfresco (ACS) est le cœur. Les autres services stockent les métadonnées, indexent le contenu, transforment les fichiers et affichent l’interface. Seuls ACS, Share et la console ActiveMQ sont accessibles depuis le navigateur ; le reste reste sur le réseau Docker.

| Composant | Rôle | Accès |
|-----------|------|--------|
| **Alfresco (ACS)** | Dépôt documentaire. Il stocke les fichiers et leurs métadonnées, applique les permissions, et expose l’API REST v1. C’est le service à appeler depuis une application. | http://localhost:8080 |
| **Share** | Interface web classique d’Alfresco. Elle sert à naviguer dans les sites, déposer des documents et créer des utilisateurs à la main. Elle parle au dépôt ; elle n’est pas l’API. | http://localhost:8081/share |
| **PostgreSQL** | Base des métadonnées (nœuds, utilisateurs, sites, permissions). Le contenu binaire n’y est pas stocké. | interne |
| **Elasticsearch** | Moteur de recherche. Il répond aux requêtes de la Search API. Solr n’est plus utilisé depuis ACS 26.2. | interne |
| **batch-indexing** | Recopie en continu les changements du dépôt vers Elasticsearch. L’index n’est donc pas instantané : un fichier qui vient d’être déposé peut mettre quelques dizaines de secondes à apparaître dans une recherche. | interne |
| **ActiveMQ** | Bus de messages entre le dépôt, l’indexation et les transformations (création de miniature, extraction de texte, conversion). La console web sert surtout au diagnostic. | http://localhost:8161 |
| **Transform Core** | Moteur de conversion (PDF, images, texte). Le dépôt l’appelle quand il doit prévisualiser ou indexer le contenu d’un fichier. | interne |

Le binaire des documents est conservé dans le volume Docker `alfresco_data`. PostgreSQL et Elasticsearch ont chacun leur volume, donc un simple redémarrage ne perd pas les données.

## Démarrage

```bash
cd infra/alfresco
cp .env.example .env
docker compose up -d
./scripts/wait-healthy.sh
./scripts/smoke-api.sh
```

Le premier démarrage prend plusieurs minutes (téléchargement des images, bootstrap de la base, index).

| Service | URL |
|---------|-----|
| API REST v1 | http://localhost:8080/alfresco/api/-default-/public/alfresco/versions/1 |
| Share | http://localhost:8081/share |
| Console ActiveMQ | http://localhost:8161 |

Compte bootstrap : `admin` / `admin` (voir `.env`).

## Arrêt

```bash
docker compose stop
```

`docker compose down -v` supprime aussi les volumes (contenu et base).
