# net-lab · Boutique en panne

Tu prends l'astreinte de la plateforme. L'équipe applicative
a déployé sa boutique hier soir, et le socle réseau
(Gateway + NetworkPolicies) a été écrit par un collègue
parti en congés. Les tickets tombent.

## Architecture prévue

```
Internet ──> Traefik ──> shop-gateway (shop-edge)
                           └─ HTTPRoute shop.local (shop)
                                ├─ /         -> frontend
                                └─ /catalog  -> catalog (shared)
frontend ──> api ──> db            (namespace shop)
prometheus (monitoring) ──> api /metrics, db
```

## Démarrer

```bash
make up      # déploie la boutique
make test    # tests de recette : tout est [KO] au départ
make status  # vue d'ensemble
make down    # tout supprimer (pour recommencer)
```

## Règles

1. Pas de `kubectl edit` : corriger les **fichiers**, puis `apply`.
2. Pas de correction sans **preuve** (la ligne de sortie qui montre la cause).
3. Valider chaque correction avec `make test`.
4. Un **commit** par ticket.
5. Ne pas modifier `tests.sh` ni le Makefile.

## Tickets

**T1 · Équipe métier** · « Le site shop.local répond 404. »
```bash
curl -H "Host: shop.local" http://<IP d'un nœud>/
```

**T2 · Équipe métier** · « Maintenant le site répond, mais
avec une erreur 502. »

**T3 · Équipe catalogue** · « La page /catalog ne marche pas.
Notre appli tourne pourtant dans le namespace shared. »

**T4 · Équipe frontend** · « Le front n'arrive pas à appeler
l'API. Chez nous, en local, ça marche. »
```bash
kubectl exec -n shop deploy/frontend -- \
  wget -qO- -T 3 http://api
```

**T5 · Équipe SRE** · « Prometheus ne récupère plus les
métriques de l'API (/metrics). »

**T6 · Équipe sécurité (audit)** · « Un pod de test lancé
dans `default` arrive à lire la base de données. C'est
bloquant pour la mise en production. Attention : l'API et
Prometheus doivent continuer à joindre la base. »
```bash
kubectl run audit -n default --rm -it \
  --restart=Never --image=busybox:1.36 -- \
  wget -qO- -T 3 http://db.shop:5432
```

## Fin du lab

`make test` affiche **7 [OK]**.

## Fiche par ticket (5 lignes)

| Symptôme | Couche | Preuve | Cause | Correction |
|---|---|---|---|---|
| | | | | |

Méthode : **d'où je pars · quel nom · qui le traduit ·
quel protocole/port · qui peut bloquer.**
