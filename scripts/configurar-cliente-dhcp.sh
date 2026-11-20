#!/usr/bin/env bash
set -euo pipefail
# Executado dentro da VM por Vagrant antes do Ansible.
mac="$(echo "$1" | sed -E 's/(..)/\1:/g;s/:$//')"
nome="$2"
iface="$(ip -o link show | awk -v m="$mac" 'tolower($0) ~ tolower(m) { gsub(/:$/, "", $2); print $2; exit }')"
[[ -n "$iface" ]] || { echo "[ASA] Não encontrei a interface com MAC $mac" >&2; exit 1; }
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq isc-dhcp-client ifupdown
cat > /etc/network/interfaces.d/asa-hostonly <<EOF
auto $iface
iface $iface inet dhcp
    metric 250
EOF
ip link set "$iface" up
# DHCP da interface NAT não deve substituir o servidor interno na resolução.
if ! grep -q '# ASA-DNS' /etc/dhcp/dhclient.conf; then
  cat >> /etc/dhcp/dhclient.conf <<'EOF'

# ASA-DNS
prepend domain-name-servers 192.168.56.112;
supersede domain-name "bruno.guilherme.devops";
EOF
fi
# Aguarda o DHCP ISC, e não o servidor do VirtualBox (desabilitado por trigger).
for tentativa in $(seq 1 12); do
  timeout 25 dhclient -1 -v "$iface" && break || true
  sleep 3
done
ip_atual="$(ip -o -4 addr show dev "$iface" | awk '{split($4,a,"/"); print a[1]; exit}')"
case "$nome:$ip_atual" in
  db:192.168.56.114|app:192.168.56.124|cli:192.168.56.50)
    echo "[ASA] $nome obteve endereço por DHCP na interface $iface: $ip_atual" ;;
  *) echo "[ASA] ERRO: o DHCP não entregou o IP esperado ao $nome ($ip_atual). Confira as concessões/leases do DHCP da arq." >&2; exit 1 ;;
esac
