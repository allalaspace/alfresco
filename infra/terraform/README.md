# Alfresco Community sur Kubernetes avec Terraform

Même stack que `infra/kubernetes/` (kustomize) et `infra/alfresco/` (Docker
Compose) : ACS Community **26.2**, Share, PostgreSQL, Elasticsearch,
batch-indexing, ActiveMQ et Transform Core.

Terraform gère les ressources Kubernetes avec le provider
`hashicorp/kubernetes` : le state est réel, la dérive est détectable, et
l'historique des changements est conservé.

> `infra/kubernetes/` reste en place et n'est pas modifié. **Les deux ne
> doivent pas être appliqués sur le même cluster** : ils déclarent les mêmes
> ressources avec les mêmes noms et attendees.

## Prérequis

- `kubectl` configuré sur un cluster joignable
- une StorageClass par défaut (les PVC l'utilisent)
- **au moins 8 Go de RAM** pour le cluster (12 Go recommandés)
- les NodePorts `30080`, `30081` et `30161` libres
- Terraform >= 1.5

Sur Docker Desktop, les NodePorts répondent sur `localhost`.

### Cible du cluster

Le provider lit le kubeconfig de l'utilisateur courant et utilise son
contexte actif, comme `kubectl`. Deux variables permettent de déroger :

| Variable | Défaut | Rôle |
|---|---|---|
| `kubeconfig_path` | `~/.kube/config` | Chemin du kubeconfig |
| `kube_context` | contexte courant | Contexte à utiliser |

Le chemin est résolu par `pathexpand()` de Terraform, et non par le provider.
La raison est propre à Windows : le provider expand `~` avec
`mitchellh/go-homedir`, qui lit la variable `HOME`. Sous Git Bash, `HOME`
vaut `/c/Users/...`, un chemin POSIX que le résolveur Go ne sait pas
développer — le kubeconfig n'est donc jamais trouvé, et le provider bascule
silencieusement sur une configuration vide, soit `http://localhost`.
`pathexpand()` passe par `USERPROFILE`, toujours un chemin Windows natif.

Si le provider reste injoignable, vérifiez la cible avant d'appliquer :

```bash
terraform plan   # doit afficher « 20 to add », pas une erreur de connexion
```


## Démarrage

Depuis ce dossier :

```bash
# 1. Générer terraform.tfvars à partir de infra/alfresco/.env
./scripts/tfvars-from-env.sh

# 2. Initialiser et appliquer
terraform init
terraform plan
terraform apply
```

`terraform.tfvars` contient les mots de passe : il est **ignoré par git**.
Pour le régénérer après une modification de `infra/alfresco/.env`, relancez
le script. Vous pouvez aussi partir de `terraform.tfvars.example` et le
modifier à la main.

### Variables sans valeur par défaut

Ces quatre variables n'ont pas de défaut et doivent être fournies, sinon
`terraform plan` échoue :

| Variable | Origine |
|---|---|
| `db_password` | `DB_PASSWORD` |
| `activemq_password` | `ACTIVEMQ_PASSWORD` |
| `transform_shared_secret` | `TRANSFORM_SHARED_SECRET` |
| `alfresco_admin_password` | `ALFRESCO_ADMIN_PASSWORD` |

Elles sont marquées `sensitive` : Terraform les masque dans la sortie et dans
le state contient les valeurs en clair. **Le state est un secret** — ne le
commitez pas.

## Composants

| Composant | Ressource | Accès |
|---|---|---|
| **Alfresco (ACS)** | Deployment + Service NodePort `30080` | http://localhost:30080 |
| **Share** | Deployment + Service NodePort `30081` | http://localhost:30081/share |
| **PostgreSQL** | Deployment + PVC `postgres-data` (8Gi) | interne, port 5432 |
| **Elasticsearch** | Deployment + PVC `elasticsearch-data` (5Gi) | interne, port 9200 |
| **batch-indexing** | Deployment | interne |
| **ActiveMQ** | Deployment + Service `61616` | console http://localhost:30161 |
| **Transform Core** | Deployment + Service `8090` | interne |
| **Content store** | PVC `alfresco-data` (10Gi) | — |

Le compte bootstrap est `admin` / `admin` (mots de passe de développement,
cf. `infra/alfresco/.env.example`). Changez-les avant tout autre usage.

## Vérification après apply

```bash
kubectl -n alfresco get pods
kubectl -n alfresco rollout status deployment/alfresco --timeout=15m
```

Le dépôt est prêt quand le Pod `alfresco` est `Running` et `READY 1/1`. Le
premier démarrage prend plusieurs minutes (téléchargement des images,
bootstrap de la base).

Sonde de démarrage :

```bash
curl -s -o /dev/null -w "%{http_code}\n" \
  http://localhost:30080/alfresco/api/-default-/public/alfresco/versions/1/probes/-ready-
```

Test de bout en bout de l'API REST (le script cible le port Compose par
défaut, d'où la variable) :

```bash
ALFRESCO_PORT=30080 ../alfresco/scripts/smoke-api.sh
```

### Deux points qui font échouer un premier apply

**Les StorageClass en `WaitForFirstConsumer`.** La StorageClass `standard`
de Docker Desktop (et celle de kind par défaut) ne provisionne le volume
qu'au moment où un pod monte le PVC. Or le provider attend que le PVC
passe `Bound` avant de créer le Deployment qui le consomme : deadlock.
Les trois PVC (`postgres-data`, `elasticsearch-data`, `alfresco-data`)
sont donc créés avec `wait_until_bound = false`. Le volume est provisionné
et lié dès que le pod est planifié.

**Les scripts `until` des init containers.** Ils doivent être joints par
un retour à la ligne, pas par un espace : `done until` est une erreur de
syntaxe pour `sh`, `done\nuntil` non. Un `join(" ", ...)` produit le
premier cas, et l'init container part en `CrashLoopBackOff` avec
`sh: syntax error: unexpected "until"`.

## Sécurité

- **Les mots de passe du keystore** (livrés dans l'image Alfresco) sont lus
  dans `infra/kubernetes/alfresco.yaml` au moment du plan, rangés dans le
  Secret Kubernetes, puis injectés dans le conteneur via `secretKeyRef` et
  référencés par `$(METADATA_KEYSTORE_PASSWORD)`. Ils n'apparaissent donc
  jamais dans la définition du Deployment. Modifier `alfresco.yaml` change le
  contenu du Secret — c'est le comportement voulu, pour rester aligné avec le
  keystore de l'image.
- **Elasticsearch** : `xpack.security.enabled` est désactivé, comme dans la
  stack kustomize, parce que le cluster local n'a pas de comptes à gérer.
  Le paramètre `elasticsearch_security_enabled` permet de le réactiver.
- **Les NodePorts** exposent Alfresco, Share et la console ActiveMQ sur
  toutes les IP des nœuds, comme la stack kustomize. Passez
  `alfresco_service_type`, `share_service_type` et `activemq_console_service_type`
  à `ClusterIP` pour ne rien exposer hors du cluster.
- `CSRF_FILTER_ORIGIN` est fixe en `http` : le filtre CSRF est désactivé
  côté Alfresco (`-Dcsrf.filter.enabled=false`), comme dans le Compose local.
  À durcir pour une exposition publique.

## Arrêt

```bash
# Tout supprimer, volumes compris
terraform destroy
```

Pour vider les Deployments en conservant les PVC :

```bash
kubectl -n alfresco scale deployment --all --replicas=0
```

## Modules

| Module | Rôle |
|---|---|
| `modules/namespace` | Namespace `alfresco` |
| `modules/configmap` | Réglages non secrets (hôte, ports, nom de base) |
| `modules/secret` | Identifiants base, ActiveMQ, admin, keystore |
| `modules/postgres` | PVC, Service, Deployment PostgreSQL |
| `modules/elasticsearch` | PVC, Service, Deployment Elasticsearch |
| `modules/activemq` | Services et Deployment ActiveMQ |
| `modules/transform-core` | Service et Deployment Transform Core |
| `modules/alfresco` | PVC, Service, Deployment ACS |
| `modules/share` | Service et Deployment Share |
| `modules/batch-indexing` | Deployment batch-indexing |

## Versions des images

Elles sont variables, avec par défaut les mêmes tags que `.env.example` et
`infra/kubernetes/README.md` :

| Image | Tag |
|---|---|
| `alfresco/alfresco-content-repository-community` | `26.2.0` |
| `alfresco/alfresco-share` | `26.2.2` |
| `alfresco/alfresco-transform-core-aio` | `5.4.4` |
| `postgres` | `17.9` |
| `elasticsearch` | `8.17.10` |
| `alfresco/alfresco-elasticsearch-batch-indexing` | `5.8.0` |
| `alfresco/alfresco-activemq` | `6.2.9-jre17-rockylinux8` |
