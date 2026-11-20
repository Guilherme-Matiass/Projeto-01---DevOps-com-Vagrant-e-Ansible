#!/usr/bin/env bash
set -euo pipefail
command -v VBoxManage >/dev/null || { echo 'VBoxManage não encontrado no hospedeiro.' >&2; exit 1; }
# Localiza exclusivamente a rede host-only que usa 192.168.56.1.
iface="$(VBoxManage list hostonlyifs | awk '
  /^Name:/ {name=$2}
  /^IPAddress:/ {if ($2=="192.168.56.1") {print name; exit}}
')"
if [[ -z "$iface" ]]; then
  echo '[ASA] Rede host-only 192.168.56.1 ainda não existe; será verificada após arq.'
  exit 0
fi
if VBoxManage dhcpserver modify --ifname "$iface" --disable >/dev/null 2>&1; then
  echo "[ASA] DHCP do VirtualBox desabilitado em $iface."
elif VBoxManage dhcpserver modify --interface "$iface" --disable >/dev/null 2>&1; then
  echo "[ASA] DHCP do VirtualBox desabilitado em $iface."
else
  # Não existe servidor VBox para esta interface? É o cenário desejado.
  if VBoxManage list dhcpservers | grep -Eq "HostInterfaceNetworking-${iface}"; then
    echo "[ASA] ERRO: o DHCP do VirtualBox em $iface não pôde ser desabilitado." >&2
    exit 1
  fi
  echo "[ASA] Nenhum servidor DHCP do VirtualBox ativo/configurado em $iface."
fi
