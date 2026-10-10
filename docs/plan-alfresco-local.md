# Plan d’architecture — Alfresco en local

**Rôle :** Architecte  
**Objectif :** Déployer Alfresco Content Services (Community) en local, le paramétrer, et valider un premier appel API REST.  
**Approche retenue :** Docker Compose (stack officielle Alfresco) — reproductible, proche d’un environnement d’intégration, sans installer Tomcat/PostgreSQL manuellement.

---

## 1. Contexte & décisions

| Décision | Choix | Justification |
|----------|--------|---------------|
| Édition | **Alfresco Community 26.2** | Gratuit pour le local / POC ; mêmes APIs REST que l’Enterprise pour le CRUD documentaire |
| Recherche | **Elasticsearch + batch-indexing** | Solr est déprécié depuis ACS 26.2 ; le secret partagé reste utilisé pour les transformations |
| Déploiement | **Docker Compose** | Standard Alfresco ; isolation ; reset facile |
| Auth locale | **Basic Auth** (admin) | Simple pour le POC ; évoluer vers OAuth2 / Identity Service en intégration |
| API cible | **Alfresco REST API v1** (`/alfresco/api/-default-/public/alfresco/versions/1`) | API moderne, documentée, adaptée aux intégrations applicatives |
| Persistances | Volumes Docker (PostgreSQL + contentstore) | Données conservées entre redémarrages |

### Hors scope (phase 1)

- Haute disponibilité, clustering
- SSO / Keycloak / Identity Service
- Customisation Share / ADF avancée
- Records Management / Governance

---

## 2. Architecture cible (local)

```
┌─────────────────────────────────────────────────────────────┐
│                     Docker Compose                          │
│                                                             │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌─────────┐ │
│  │ Alfresco │──▶│ Postgres │   │Elasticsearch│  │ ActiveMQ│ │
│  │   ACS    │   │          │   │ + batch-index│  │         │ │
│  │ :8080    │   └──────────┘   └──────────────┘  └─────────┘ │
│  └────┬─────┘                                               │
│       │         ┌──────────┐   ┌──────────┐                 │
│       ├────────▶│ Transform│   │  Share   │                 │
│       │         │  Core    │   │  :8081   │                 │
│       │         └──────────┘   └──────────┘                 │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │ HTTPS/HTTP + Basic Auth
                              │
                    ┌─────────┴─────────┐
                    │ App / curl / Postman│
                    │  REST API v1       │
                    └───────────────────┘
```

### Ports exposés (référence)

| Service | Port hôte | Usage |
|---------|-----------|--------|
| Alfresco (ACS) | `8080` | API REST + Repository |
| Share | `8081` | UI classique |
| PostgreSQL | interne | Métadonnées |
| Elasticsearch | interne | Indexation |
| ActiveMQ | `8161` | Console messaging |

Les fichiers prêts à l’emploi sont dans `infra/alfresco/`.

---

## 3. Prérequis machine

- Docker Desktop ≥ 4.x / Docker Engine + Compose v2
- **RAM allouée à Docker : ≥ 8 Go** (12–16 Go recommandé)
- CPU : ≥ 4 cœurs
- Disque libre : ≥ 20 Go
- Outils : `curl`, `jq` (optionnel), Postman ou Insomnia

Vérification rapide :

```bash
docker --version
docker compose version
```

---

## 4. Paramétrage

### 4.1 Variables d’environnement (fichier `.env`)

À placer à la racine du dossier d’installation Alfresco (ex. `infra/alfresco/.env`) :

```env
# Voir infra/alfresco/.env.example pour la liste complète.
ALFRESCO_PORT=8080
SHARE_PORT=8081
DB_PASSWORD=alfresco
ALFRESCO_ADMIN_USER=admin
ALFRESCO_ADMIN_PASSWORD=admin
```

### 4.2 Paramètres Repository (principaux)

| Paramètre | Valeur locale typique | Rôle |
|-----------|----------------------|------|
| `db.driver` | `org.postgresql.Driver` | Driver JDBC |
| `db.url` | `jdbc:postgresql://postgres:5432/alfresco` | Connexion BDD |
| `db.username` / `db.password` | (secrets compose) | Auth BDD |
| `alfresco.host` | `localhost` | Host annoncé aux clients |
| `alfresco.port` | `8080` | Port annoncé |
| `alfresco.protocol` | `http` | Protocole local |
| `index.subsystem.name` | `elasticsearch` | Moteur de recherche |
| `elasticsearch.host` | `elasticsearch` | Nœud d’indexation |
| `messaging.broker.url` | `failover:(nio://activemq:61616)` | ActiveMQ |
| `csrf.filter.enabled` | `false` (dev only) | Facilite les appels depuis outils externes |

### 4.3 Sécurité — règles pour le local

1. Ne pas committer `.env` ni mots de passe (ajouter à `.gitignore`).
2. Compte `admin` uniquement pour bootstrap ; créer un utilisateur technique `svc-integration` pour les appels API.
3. En phase 2 : basculer vers OAuth2 (Identity Service / Keycloak) et désactiver Basic Auth côté applicatif.

### 4.4 Structure de dossiers recommandée

```
cursorproject/
├── docs/
│   └── plan-alfresco-local.md      ← ce document
├── infra/
│   └── alfresco/
│       ├── docker-compose.yml
│       ├── .env.example
│       ├── .env                    ← gitignored
│       └── scripts/
│           ├── wait-healthy.sh
│           └── smoke-api.sh
└── clients/
    └── api-examples/
        ├── curl-examples.http
        └── README.md
```

---

## 5. Installation (pas à pas)

### Étape A — Aller dans la stack livrée

```bash
cd infra/alfresco
```

Le `docker-compose.yml` fige ACS Community 26.2, Share, PostgreSQL 17, Elasticsearch 8.17, batch-indexing, ActiveMQ et Transform Core.

### Étape B — Configurer

```bash
cp .env.example .env
# Ajuster les ports si 8080, 8081 ou 8161 sont déjà pris
```

Points de contrôle avant `up` :

- [ ] Ports `8080` / `5432` libres
- [ ] Docker a ≥ 8 Go RAM
- [ ] `.env` non versionné

### Étape C — Démarrer

```bash
docker compose up -d
docker compose ps
docker compose logs -f alfresco   # ou nom du service repository
```

**Temps de premier démarrage :** 5 à 15 minutes (init BDD + Elasticsearch + bootstrap).

```bash
./scripts/wait-healthy.sh
./scripts/smoke-api.sh
```

### Étape D — Healthcheck

```bash
# Repository up ?
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/alfresco/api/-default-/public/alfresco/versions/1/probes/-ready-

# Authentification admin (Basic)
curl -u admin:admin \
  "http://localhost:8080/alfresco/api/-default-/public/alfresco/versions/1/people/-me-"
```

Critères de succès :

- Probe ready → `200`
- `/people/-me-` → JSON avec `"id": "admin"`

### Étape E — Utilisateur technique (recommandé)

Via Share (`http://localhost:8081/share`) ou API Admin :

1. Créer l’utilisateur `svc-integration`
2. Lui donner un site / dossier de travail (ex. site `poc-api`)
3. Stocker les credentials dans un secret local (pas dans le code)

---

## 6. Appel API Alfresco

### 6.1 Base URL & auth

```
BASE=http://localhost:8080/alfresco/api/-default-/public/alfresco/versions/1
AUTH=-u admin:admin
# ou : -u svc-integration:<password>
```

Header utile pour les uploads :

```
Content-Type: multipart/form-data   # upload
Accept: application/json
```

### 6.2 Scénario smoke-test (ordre d’exécution)

#### 1) Qui suis-je ?

```bash
curl -s $AUTH "$BASE/people/-me-" | jq .
```

#### 2) Lister les sites

```bash
curl -s $AUTH "$BASE/sites" | jq .
```

#### 3) Créer un site (si besoin)

```bash
curl -s $AUTH -H "Content-Type: application/json" \
  -d '{"id":"poc-api","title":"POC API","visibility":"PRIVATE"}' \
  "$BASE/sites"
```

#### 4) Récupérer le `nodeId` du documentLibrary du site

```bash
curl -s $AUTH "$BASE/sites/poc-api/containers" | jq .
# Repérer l'entry "documentLibrary" → id du nœud
```

#### 5) Uploader un fichier

```bash
NODE_ID="<id-documentLibrary>"

curl -s $AUTH \
  -F "filedata=@./exemple.pdf" \
  -F "name=exemple.pdf" \
  -F "autoRename=true" \
  "$BASE/nodes/$NODE_ID/children"
```

#### 6) Lire les métadonnées du nœud créé

```bash
FILE_NODE_ID="<id-retour-upload>"

curl -s $AUTH "$BASE/nodes/$FILE_NODE_ID" | jq .
```

#### 7) Télécharger le contenu

```bash
curl -s $AUTH -o telecharger.pdf \
  "$BASE/nodes/$FILE_NODE_ID/content"
```

#### 8) Recherche (Search API — endpoint distinct)

```bash
curl -s $AUTH -H "Content-Type: application/json" \
  -d '{"query":{"query":"exemple.pdf"}}' \
  "http://localhost:8080/alfresco/api/-default-/public/search/versions/1/search"
```

### 6.3 Contrat d’intégration applicative (recommandation archi)

| Couche | Responsabilité |
|--------|----------------|
| **Client métier** | Jamais d’appel direct Alfresco depuis le navigateur avec Basic Auth admin |
| **BFF / microservice `document-service`** | Encapsule REST Alfresco ; gère auth, retries, mapping DTO |
| **Alfresco** | Source de vérité documentaire (content + métadonnées + permissions) |

Endpoints minimaux à exposer côté BFF en phase 1 :

- `POST /documents` → upload Alfresco
- `GET /documents/{id}` → métadonnées
- `GET /documents/{id}/content` → binaire
- `DELETE /documents/{id}` → soft/hard delete selon politique

---

## 7. Plan de livraison (jalons)

| Jalon | Livrable | Critère de done |
|-------|----------|-----------------|
| **J1** | Compose + `.env.example` + doc ports | Stack `up`, probe ready |
| **J2** | Script `smoke-api.sh` | Upload + download OK |
| **J3** | Utilisateur technique + site `poc-api` | Auth non-admin fonctionnelle |
| **J4** | Esquisse BFF (OpenAPI) | Contrat d’API validé avec l’équipe |
| **J5** | Checklist passage intégration | Secrets, OAuth, backups volumes |

---

## 8. Risques & mitigations

| Risque | Impact | Mitigation |
|--------|--------|------------|
| RAM Docker insuffisante | ACS ne démarre pas / OOM | Allouer 12 Go ; réduire `-Xmx` transform si besoin |
| Premier boot long | Faux négatif healthcheck | Script `wait-healthy` avec timeout 10 min |
| Versions d’images incohérentes | Bugs search/transform | Utiliser un compose officiel versionné (tag unique) |
| Basic Auth en prod | Fuite credentials | Interdit hors local ; OAuth dès l’intégration |
| Volumes non sauvegardés | Perte de POC | Documenter `docker compose down -v` comme destructif |

---

## 9. Critères d’acceptation (phase locale)

- [ ] `docker compose up -d` démarre tous les services healthy
- [ ] `GET /people/-me-` retourne 200 avec Basic Auth
- [ ] Création de site + upload + download via REST API v1
- [ ] La Search API retourne le fichier uploadé (indexation Elasticsearch asynchrone, quelques dizaines de secondes)
- [ ] `.env` exclu du dépôt ; `.env.example` documenté
- [ ] Script smoke automatisé exécutable en CI locale

---

## 10. Prochaines actions concrètes

1. Lancer `docker compose up -d` dans `infra/alfresco`, puis `./scripts/smoke-api.sh`.
2. Valider avec l’équipe le besoin OAuth / Identity Service pour l’environnement suivant.

---

*Document vivant — à mettre à jour dès que la version ACS et le mode d’auth cible sont figés.*
