#!/usr/bin/env bash
set -euo pipefail
# LVM apenas na VM arq. Reconhece os discos extras por tamanho, sem presumir /dev/sdb.
# NÃO inicializa discos já montados, particionados ou com assinaturas.
if ! vgs dados >/dev/null 2>&1; then
  mapfile -t discos < <(lsblk -dnbo NAME,SIZE,TYPE | awk '$3 == "disk" && $2 >= 9500000000 && $2 <= 11500000000 {print "/dev/"$1}')
  if [[ ${#discos[@]} -ne 3 ]]; then
    echo "[ASA] Esperava exatamente 3 discos extras vazios de ~10 GB; encontrei ${#discos[@]}." >&2
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT >&2
    exit 1
  fi
  for disco in "${discos[@]}"; do
    if [[ -n "$(lsblk -nro MOUNTPOINT "$disco" | tr -d '[:space:]')" ]]; then
      echo "[ASA] $disco está montado; interrompendo para proteger os dados." >&2; exit 1
    fi
    if [[ $(lsblk -nro TYPE "$disco" | wc -l) -gt 1 ]]; then
      echo "[ASA] $disco tem partições/filhos; interrompendo." >&2; exit 1
    fi
    if blkid "$disco" >/dev/null 2>&1 || wipefs -n "$disco" | grep -q .; then
      echo "[ASA] $disco tem assinaturas; interrompendo." >&2; exit 1
    fi
  done
  pvcreate -y "${discos[@]}"
  vgcreate dados "${discos[@]}"
  echo ALTERADO
fi
if ! lvs dados/ifpb >/dev/null 2>&1; then
  lvcreate -L 15G -n ifpb dados
  echo ALTERADO
fi
if [[ "$(blkid -o value -s TYPE /dev/dados/ifpb || true)" != 'ext4' ]]; then
  if blkid /dev/dados/ifpb >/dev/null 2>&1; then
    echo '[ASA] Volume já possui outro sistema de arquivos; não vou sobrescrever.' >&2
    exit 1
  fi
  mkfs.ext4 -F /dev/dados/ifpb
  echo ALTERADO
fi
