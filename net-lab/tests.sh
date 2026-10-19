#!/usr/bin/env bash
# Tests de recette de la boutique.
# Chaque ligne : [OK] ou [KO] + le ticket concerné.
NODE_IP=$(kubectl get nodes -o \
  jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

check () { # $1 ticket, $2 description, reste = commande
  t="$1"; d="$2"; shift 2
  if "$@" >/dev/null 2>&1; then
    echo "[OK] $t  $d"
  else
    echo "[KO] $t  $d"
  fi
}

web () { # $1 chemin, $2 texte attendu
  curl -s -m 5 -H "Host: shop.local" \
    "http://${NODE_IP}$1" | grep -q "$2"
}

podget () { # $1 ns, $2 deploy, $3 url, $4 texte attendu
  kubectl exec -n "$1" "deploy/$2" -- \
    wget -qO- -T 3 "$3" 2>/dev/null | grep -q "$4"
}

audit_blocked () {
  ! kubectl run audit-$RANDOM -n default --rm -i \
    --restart=Never --image=busybox:1.36 -- \
    wget -qO- -T 3 http://db.shop:5432 2>/dev/null \
    | grep -q db-ok
}

check T1-T2 "Site shop.local accessible" \
  web / front-ok
check T3    "Page /catalog accessible" \
  web /catalog catalog-ok
check T4    "Front joint l'API" \
  podget shop frontend http://api api-ok
check T5    "Monitoring lit /metrics de l'API" \
  podget monitoring prometheus \
  http://api.shop/metrics api_requests_total
check T6    "Base fermée à un pod quelconque" \
  audit_blocked
check T6    "API joint toujours la base" \
  podget shop api http://db:5432 db-ok
check T6    "Prometheus joint toujours la base" \
  podget monitoring prometheus \
  http://db.shop:5432 db-ok
