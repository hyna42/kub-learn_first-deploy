# debug-lab — Diagnostiquer des pannes Kubernetes

Lab pratique de la leçon 9/9 du module 4 (« Débugger une application ») du parcours Kubernetes de Stéphane Robert.
Cluster : k3d `app-cluster` (1 server, 2 agents).

## Objectif

Un namespace contenant **8 ressources, chacune avec une panne différente**.
Le but est de les diagnostiquer **à partir des symptômes**, sans lire le YAML, comme sur un cluster dont on hériterait.

| Fichier | Rôle |
|---|---|
| `debug-lab.template.yaml` | Manifest **cassé** : point de départ pour refaire le lab |
| `debug-lab.yaml` | Manifest **corrigé** : mes solutions |
| `batch-config.yaml` | ConfigMap créée pendant le lab (**ignorée par git**, contient des identifiants) |

## Lancer / nettoyer

```bash
# Créer le namespace de façon déclarative (évite le warning last-applied-configuration)
k create ns debug-lab --dry-run=client -o yaml | k apply -f -
k apply -f debug-lab.template.yaml --dry-run=server
k apply -f debug-lab.template.yaml
k config set-context --current --namespace=debug-lab

# Nettoyage
k delete ns debug-lab
k config set-context --current --namespace=default
```

> Le `--dry-run=server` échoue si le namespace n'existe pas encore : un dry-run ne crée rien,
> même pas le namespace. Le créer d'abord, valider le reste ensuite.

## Méthode : symptôme d'abord, cours ensuite

Pour chaque ressource :

1. **Observer** : le STATUS dans `k get po`, la ligne de la ressource dans `k get events`.
2. **Choisir** les 2 commandes adaptées au symptôme (tableau ci-dessous).
3. **Formuler une hypothèse** : « je pense que c'est X parce que je vois Y ».
4. **Vérifier** dans la section du cours correspondant au symptôme.
5. **Corriger** : `--dry-run=server`, `diff`, puis `apply`.
6. **Prouver** que c'est réparé (Pod sain, endpoints présents, test fonctionnel).

### Tableau de décision

| Symptôme | 1re commande | 2e commande |
|---|---|---|
| `CrashLoopBackOff` | `k logs <pod> --previous` | `k describe po <pod>` |
| `Pending` | `k describe po <pod>` | `k get events` |
| `Running` mais appli KO | `k logs <pod>` | `k port-forward` / test réseau |
| `Running` mais appli **lente** | `k top po` comparé à `limits.cpu` | `k exec <pod> -- cat /sys/fs/cgroup/cpu.stat` |
| Image sans shell | `k debug -it <pod> --image=busybox:1.37 --target=<conteneur>` | `ps`, `ss`, `nslookup` |
| Suspicion OOM | `k describe po <pod>` (Last State, Exit Code) | `k top po` |
| Problème de Service | `k get endpointslice` | `k port-forward` / `wget` depuis un Pod |

## Solutions

| Ressource | Symptôme | Commande qui a donné la réponse | Cause | Correctif |
|---|---|---|---|---|
| **api** | `CrashLoopBackOff` (exit 1) | `k logs api --previous` → `FATAL: DATABASE_URL not set` | Variable d'environnement absente | Ajout de `env: DATABASE_URL`, puis **delete + apply** (`env` d'un Pod est immuable) |
| **worker** | `ImagePullBackOff` | `k describe po worker` (sur un échec récent) | Tag `nginx:1.99.9` inexistant | Tag `1.31.6`, **simple apply** (l'image d'un Pod est modifiable) |
| **reports** | `Pending` | `describe` → `FailedScheduling … Insufficient cpu` | `requests.cpu: "64"` = 64 cœurs, aucun nœud ne les a | `10m`, puis **delete + apply** (resources immuables sur un Pod) |
| **cache** | `OOMKilled` ⇄ `CrashLoopBackOff` (exit 137) | `describe` → `Last State: OOMKilled`, `Exit Code: 137` | Alloue 250M (≈ 238Mi), limite à 100Mi | `limits.memory` au-dessus de 238Mi avec marge, puis **delete + apply** |
| **batch** | `CreateContainerConfigError` | `describe` → `configmap "batch-config" not found` | ConfigMap référencée par `envFrom` inexistante | Création de la ConfigMap. Le **kubelet réessaie seul**, aucun redémarrage nécessaire |
| **front** | `Running` **0/1** | `k get endpointslice` → `ready=false` | readinessProbe sur `/healthz` → 404 (n'existe pas dans nginx) | Probe sur `/`, **simple apply** (Deployment → nouveau ReplicaSet) |
| **web** | `Running` 1/1 (piège) | `k get endpointslice` → `web-svc <unset>` | Selector du Service `app=website`, Pods étiquetés `app=web` | Selector du **Service** corrigé en `app=web` (Pods déjà bons, selector du Deployment immuable) |
| **legacy** | Aucun (pas cassé) | `k exec -it legacy -- sh` → `"sh": executable file not found` | Image minimale (`pause`), pas de shell | `k debug -it legacy --image=busybox:1.37 --target=app` |

## Leçons apprises

### Lire les erreurs
- **La vraie cause est à la fin du message.** Tout ce qui précède (`Internal error`, `OCI runtime exec failed`…) est la chaîne kubectl → API → kubelet → runtime.
- **Les Events ont un âge.** Comparer `LAST SEEN` / `Age` avec `State: Running → Started` : un Event plus ancien que le démarrage décrit le passé. Les Events expirent après ~1 h (`Events: <none>`).
- **`x95 over 39m`** = l'Event s'est répété 95 fois en 39 minutes : le système réessaie.
- **Même erreur, même seconde, sur tous les Pods** = cause commune (nœud, DNS, registre), pas applicative.
  Exemple vécu : `FailedCreatePodSandBox … lookup registry-1.docker.io: Try again` = DNS du nœud temporairement indisponible.
- **Colonne RESTARTS** : un chiffre qui augmente = crash en boucle. Plusieurs Pods redémarrés à la même minute = reboot VM / cluster. Le Pod qui sort du lot est celui à creuser.

### « Running » ne veut pas dire « ça marche »
Vérification complète en 4 niveaux :
```bash
k get po                                                      # READY complet, RESTARTS stable
k get events --field-selector type=Warning --sort-by=.lastTimestamp
k get endpointslice                                           # chaque Service a des adresses
k run test-net --rm -it --image=busybox:1.37 -- wget -qO- http://<service>
```

### Immuable ou pas : apply simple ou delete + apply ?
- Sur un **Pod nu**, presque tout est immuable (`env`, `resources`, `command`…). Seuls l'image et quelques champs sont modifiables. Le `--dry-run=server` le signale : `pod updates may not change fields other than…` → `delete` + `apply` (ou `k replace --force -f`).
- Un **Deployment** accepte la modification : il crée un nouveau ReplicaSet et de nouveaux Pods.

### Quand faire (ou pas) un `rollout restart`
- `rollout restart` ne marche que sur **Deployment, DaemonSet, StatefulSet**. Sur un Pod nu : `pods "x" restarting is not supported`.
- **Inutile** quand on crée ce qui **manquait** (ConfigMap, Secret absents) : le kubelet réessaie seul.
- **Nécessaire** quand on **modifie** une ConfigMap ou un Secret **déjà injecté en variables d'environnement** : les variables ne sont lues qu'au démarrage du conteneur.

### Pièges rencontrés
- **Un correctif qui ne change rien** → relire ce que fait vraiment le conteneur (`command`, logs) au lieu de supposer.
- **ResourceQuota sans LimitRange** : un quota sur CPU/mémoire exige que chaque Pod déclare requests et limits. Sans LimitRange pour injecter des défauts, le ReplicaSet échoue (`failed quota … must specify limits.cpu`) : à lire dans `k describe rs`, pas dans les Pods (ils n'existent pas).
- **Le `--dry-run=server` valide le Deployment, pas les Pods** créés ensuite par le ReplicaSet.
- **Backoff du ReplicaSet** : après une correction, il peut attendre plusieurs minutes avant de réessayer.
- **Mot de passe dans une ConfigMap** : à éviter. Les données sensibles vont dans un **Secret** (`secretRef` au lieu de `configMapRef`).
- **`port-forward` : `address already in use`** → `sudo ss -tlnp | grep <port>` pour trouver le processus qui occupe le port.

### kubectl debug
- `kubectl exec` lance un programme **qui existe déjà dans l'image**. Image minimale / distroless → pas de shell.
- `kubectl debug` ajoute un **conteneur éphémère** au Pod en cours d'exécution, sans le redémarrer.
- `--target=<conteneur>` partage la liste de processus du conteneur ciblé (`ps aux`, `/proc/1/root/`).
- La session est enregistrée dans les logs du conteneur : **ne jamais taper de secret**.

## Commandes utiles

```bash
k get po -w                                           # suivre en direct
k describe po <pod> | grep -A5 "Last State"           # raison et code du dernier arrêt
k get events --field-selector involvedObject.name=<pod>
k get svc <svc> -o jsonpath='{.spec.selector}'; echo  # ce que cherche le Service
k get po --show-labels                                # ce que portent les Pods
k get endpointslice -l kubernetes.io/service-name=<svc> \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]} ready={.conditions.ready}{"\n"}{end}'
```

| Exit code | Signification |
|---|---|
| `0` | Fin normale (`Completed`) |
| `1` | Erreur applicative : lire les logs |
| `137` | SIGKILL (128 + 9) : OOMKilled ou kill forcé |