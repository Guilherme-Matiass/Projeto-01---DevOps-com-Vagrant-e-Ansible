#!/usr/bin/env bash
set -euo pipefail
# Após a VM arq estar com DNS funcional: registra SOMENTE o dominio ASA no resolved.
# Não adiciona arq/db/app ao /etc/hosts. O cli será a unica entrada manual de /etc/hosts.
dominio=bruno.guilherme.devops
servidor=192.168.56.112
if getent hosts "arq.$dominio" >/dev/null 2>&1; then
  echo '[ASA] Resolucao DNS no hospedeiro ja esta funcional.'; exit 0
fi
iface="$(ip -o -4 addr show | awk '$4 == "192.168.56.1/24" {print $2; exit}')"
if [[ -z "$iface" ]]; then
  echo '[ASA] AVISO: interface host-only 192.168.56.1 nao encontrada; teste ping arq.* no hospedeiro.' >&2
  exit 0
fi
if command -v resolvectl >/dev/null 2>&1 && resolvectl status >/dev/null 2>&1; then
  echo "[ASA] Configurando DNS restrito a *.$dominio em $iface (pode pedir senha sudo)."
  if sudo resolvectl dns "$iface" "$servidor" && \
     sudo resolvectl domain "$iface" "~$dominio"; then
    sudo resolvectl flush-caches || true
    if getent hosts "arq.$dominio" >/dev/null 2>&1; then
      echo '[ASA] DNS do dominio ASA disponivel no hospedeiro.'
      exit 0
    fi
  fi
fi
echo '[ASA] ATENCAO: DNS do hospedeiro ainda nao resolveu arq.bruno.guilherme.devops.' >&2
echo '[ASA] Necessario configurar DNS por interface no seu NetworkManager/resolved; nao editar /etc/hosts para arq/db/app.' >&2
# Um resolved ausente nao deve impedir o vagrant up de concluir.
exit 0
