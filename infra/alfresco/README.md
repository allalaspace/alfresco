# Alfresco Community en local

Stack ACS **26.2** : repository, Share, PostgreSQL, Elasticsearch, batch-indexing, ActiveMQ, transform core.

## Composants

Le dépôt Alfresco (ACS) est le cœur. Les autres services stockent les métadonnées, indexent le contenu, transforment les fichiers et affichent l’interface. Seuls ACS, Share et la console ActiveMQ sont accessibles depuis le navigateur ; le reste reste sur le réseau Docker.

| Composant | Rôle | Accès |
|-----------|------|--------|
| **Alfresco (ACS)** | Dépôt documentaire. Il stocke les fichiers et leurs métadonnées, applique les permissions, et expose l’API REST v1. C’est le service à appeler depuis une application. | http://127.0.0.1:8080 |
| **Share** | Interface web classique d’Alfresco. Elle sert à naviguer dans les sites, déposer des documents et créer des utilisateurs à la main. Elle parle au dépôt ; elle n’est pas l’API. | http://127.0.0.1:8081/share |
| **PostgreSQL** | Base des métadonnées (nœuds, utilisateurs, sites, permissions). Le contenu binaire n’y est pas stocké. | interne |
| **Elasticsearch** | Moteur de recherche. Il répond aux requêtes de la Search API. Solr n’est plus utilisé depuis ACS 26.2. | interne |
| **batch-indexing** | Recopie en continu les changements du dépôt vers Elasticsearch. L’index n’est donc pas instantané : un fichier qui vient d’être déposé peut mettre quelques dizaines de secondes à apparaître dans une recherche. | interne |
| **ActiveMQ** | Bus de messages entre le dépôt, l’indexation et les transformations (création de miniature, extraction de texte, conversion). La console web sert surtout au diagnostic. | http://127.0.0.1:8161 |
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
| API REST v1 | http://127.0.0.1:8080/alfresco/api/-default-/public/alfresco/versions/1 |
| Share | http://127.0.0.1:8081/share |
| Console ActiveMQ | http://127.0.0.1:8161 |

Les ports sont liés à `127.0.0.1`. PostgreSQL, Elasticsearch et Transform ne sont pas publiés. Compte bootstrap : `admin` / `admin` (voir `.env`). Avant un accès distant, change ce mot de passe dans Share, puis reporte-le dans `ALFRESCO_ADMIN_PASSWORD`.

Sauvegarde de la base et du contenu :

```powershell
.\scripts\backup.ps1
```

## Accès distant — Cloudflare Tunnel

Le tunnel ouvre une connexion sortante vers Cloudflare. La box n’a pas de port entrant à rediriger, et une IP publique fixe n’est pas nécessaire. Le domaine doit être géré par Cloudflare.

Seul le web est publié, via Caddy : `/share` vers Share, le reste vers le dépôt. PostgreSQL, Elasticsearch, ActiveMQ et Transform restent internes.

1. Vérifie d’abord le local (`docker compose up -d`, Share, sonde ready).
2. Dans Share, remplace le mot de passe `admin`.
3. Dans Cloudflare Zero Trust : **Networks → Tunnels → Create a tunnel → Cloudflared**. Copie le jeton dans `.env` :

```env
CLOUDFLARE_TUNNEL_TOKEN=le-jeton
ALFRESCO_PUBLIC_HOST=alfresco.ton-domaine.fr
ALFRESCO_PROTOCOL=https
ALFRESCO_PUBLIC_PORT=443
SHARE_PUBLIC_PORT=443
ALFRESCO_PUBLIC_BASEURL=https://alfresco.ton-domaine.fr
SHARE_PUBLIC_ORIGIN=https://alfresco.ton-domaine.fr
```

`SHARE_PUBLIC_ORIGIN` est sans barre finale et sans `:443` : le navigateur envoie `https://alfresco.ton-domaine.fr`.

4. Sur le tunnel, ajoute un hostname public :

| Champ | Valeur |
|-------|--------|
| Sous-domaine | `alfresco` |
| Domaine | `ton-domaine.fr` |
| Type | HTTP |
| URL | `caddy:80` |

Dans les réglages additionnels, mets l’en-tête HTTP Host à `alfresco.ton-domaine.fr`. N’ajoute pas de route vers PostgreSQL, Elasticsearch ou ActiveMQ.

5. Dans **Access → Applications**, crée une application self-hosted sur ce hostname et une règle **Allow** limitée à tes adresses e-mail (code à usage unique). Sans cette règle, l’instance est ouverte à tout Internet.

6. Démarre le profil et recrée le dépôt et Share pour qu’ils annoncent le nom public :

```bash
docker compose --profile tunnel up -d
```

| URL publique | Rôle |
|--------------|------|
| https://alfresco.ton-domaine.fr/share | Share |
| https://alfresco.ton-domaine.fr/alfresco | Dépôt et API |

La machine doit rester allumée : le tunnel ne lui ajoute ni CPU ni RAM. Ce Compose sert au développement et aux essais ; un déploiement de production demande une configuration adaptée. Relance `.\scripts\backup.ps1` régulièrement.

## Arrêt

```bash
docker compose stop
```

`docker compose down -v` supprime aussi les volumes (contenu et base).

## Kubernetes

La même stack est décrite pour Kubernetes dans [`infra/kubernetes`](../kubernetes/README.md) (`kubectl apply -k infra/kubernetes`). Les images, variables et volumes suivent ce Compose. Les ports publics y sont `30080` (ACS), `30081` (Share) et `30161` (console ActiveMQ).
