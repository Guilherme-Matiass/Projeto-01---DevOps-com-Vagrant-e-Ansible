#!/usr/bin/env bash
# Verifica o laboratorio ASA sem alterar os servicos das VMs.
# Nao executa o avaliador do professor nem cria/remove usuarios.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ" || exit 1
DOMINIO="bruno.guilherme.devops"
PASTA_LOG="$RAIZ/relatorios"
mkdir -p "$PASTA_LOG"
LOG="$PASTA_LOG/verificacao-$(date +%Y%m%d-%H%M%S).txt"
exec > >(tee "$LOG") 2>&1

PASSOU=0; FALHOU=0; AVISO=0
passar() { printf '[OK] %s\n' "$1"; PASSOU=$((PASSOU+1)); }
falhar() { printf '[FALHA] %s\n' "$1"; FALHOU=$((FALHOU+1)); }
aviso() { printf '[AVISO] %s\n' "$1"; AVISO=$((AVISO+1)); }
teste() { local descricao="$1"; shift; if "$@" >/dev/null 2>&1; then passar "$descricao"; else falhar "$descricao"; fi; }
remoto() {
  local maquina="$1" usuario="$2" comando="$3"
  command -v ssh >/dev/null 2>&1 || return 127
  ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=accept-new \
    -o IdentitiesOnly=yes -i "$RAIZ/keys/$usuario" \
    "$usuario@$maquina.$DOMINIO" "$comando"
}
vm_ip() { remoto "$1" bruno "ip -o -4 addr show | grep -q 'inet $2/'"; }
resolver_ip() {
  local ip="$1" host="$2"
  getent ahostsv4 "$host" | awk -v ip="$ip" '$1 == ip { encontrou=1 } END {exit !encontrou}'
}
so_cli_hosts() {
  awk '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ {next}
    {
      for (i=2; i<=NF; i++) {
        if ($i ~ /^(arq|db|app)(\.bruno\.guilherme\.devops)?$/) exit 1
      }
    }
  ' /etc/hosts
}
cli_hosts() {
  awk '
    /^[[:space:]]*#/ {next}
    $1 == "192.168.56.50" {
      curto=0; completo=0
      for (i=2;i<=NF;i++) {
        if ($i=="cli") curto=1
        if ($i=="cli.bruno.guilherme.devops") completo=1
      }
      if (curto && completo) ok=1
    }
    END {exit !ok}
  ' /etc/hosts
}

printf 'ASA - Revisao final (somente leitura)\nGerado em: %s\n\n' "$(date -Is)"
for executavel in vagrant ssh getent curl; do
  teste "Comando instalado: $executavel" command -v "$executavel"
done
if command -v vagrant >/dev/null 2>&1; then
  printf '\n--- Estado do Vagrant ---\n'
  vagrant status || aviso 'Nao foi possivel consultar o status das VMs'
fi
printf '\n--- Chaves e resolucao de nomes ---\n'
for usuario in bruno guilherme; do
  teste "Chave privada do $usuario gerada automaticamente" test -s "keys/$usuario"
  teste "Chave publica do $usuario presente" test -s "keys/$usuario.pub"
done
for par in 'arq 192.168.56.112' 'db 192.168.56.114' 'app 192.168.56.124'; do
  read -r nome ip <<<"$par"
  teste "DNS hospedeiro: $nome.$DOMINIO -> $ip" resolver_ip "$ip" "$nome.$DOMINIO"
done
teste 'Somente cli pode ser mapeado manualmente no /etc/hosts' so_cli_hosts
teste 'Linha cli 192.168.56.50 presente no /etc/hosts' cli_hosts
teste "cli.$DOMINIO resolve para 192.168.56.50" resolver_ip '192.168.56.50' "cli.$DOMINIO"

printf '\n--- SSH: dois usuarios nas quatro VMs ---\n'
for vm in arq db app cli; do
  for usuario in bruno guilherme; do
    teste "SSH $usuario@$vm e sudo sem senha" remoto "$vm" "$usuario" "sudo -n id '$usuario'"
  done
done

printf '\n--- Rede e DHCP ---\n'
for par in 'arq 192.168.56.112' 'db 192.168.56.114' 'app 192.168.56.124' 'cli 192.168.56.50'; do
  read -r nome ip <<<"$par"
  teste "$nome tem o IP $ip" vm_ip "$nome" "$ip"
done
teste 'Servidor DHCP da arq ativo' remoto arq bruno 'sudo -n systemctl is-active --quiet isc-dhcp-server'
teste 'Pool DHCP dinamico .50 a .100' remoto arq bruno "sudo -n grep -Eq 'range[[:space:]]+192\\.168\\.56\\.50[[:space:]]+192\\.168\\.56\\.100;' /etc/dhcp/dhcpd.conf"
teste 'CLI configurado para solicitar IP por DHCP' remoto cli bruno "grep -Eq '^[[:space:]]*iface[[:space:]]+[^[:space:]]+[[:space:]]+inet[[:space:]]+dhcp' /etc/network/interfaces.d/asa-hostonly"
teste 'Servidor Bind9 da arq ativo' remoto arq bruno 'sudo -n systemctl is-active --quiet bind9'

printf '\n--- Seguranca SSH, tempo e servicos ---\n'
for vm in arq db app cli; do
  teste "Chrony sincronizado em $vm" remoto "$vm" bruno "chronyc sources | grep -q '^\\^\\*'"
  teste "SSH sem senha e sem root em $vm" remoto "$vm" bruno "sudo -n sshd -T | grep -qx 'passwordauthentication no' && sudo -n sshd -T | grep -qx 'permitrootlogin no'"
done
teste 'VG dados com 3 PVs' remoto arq bruno "sudo -n pvs --noheadings -o vg_name | awk '\$1 == \"dados\" {n++} END {exit n!=3}'"
teste 'LV dados/ifpb de 15 GiB' remoto arq bruno "sudo -n lvs --noheadings -o lv_size --units g --nosuffix dados/ifpb | awk '{ok=(\$1 >= 14.9 && \$1 <= 15.1); seen=1} END {exit !(seen && ok)}'"
teste 'LV ext4 montado automaticamente em /dados' remoto arq bruno "findmnt -n -o FSTYPE /dados | grep -qx ext4 && grep -q '^/dev/dados/ifpb /dados ext4 ' /etc/fstab"
teste 'Compartilhamento NFS exportado' remoto arq bruno "sudo -n exportfs -v | grep -q '/dados/nfs'"
teste 'MariaDB ativo em db' remoto db bruno 'sudo -n systemctl is-active --quiet mariadb'
teste 'Apache ativo em app' remoto app bruno 'sudo -n systemctl is-active --quiet apache2'
for vm in db app cli; do
  teste "autofs ativo em $vm" remoto "$vm" bruno 'sudo -n systemctl is-active --quiet autofs'
  teste "NFS montavel em /var/nfs em $vm" remoto "$vm" bruno "timeout 15 sh -c 'ls /var/nfs/. >/dev/null && findmnt -n -T /var/nfs -o FSTYPE | grep -Eq \"^(nfs|nfs4)\$\"'"
done

printf '\n--- Pagina web e cliente grafico ---\n'
if html="$(curl -fsS --max-time 12 "http://app.$DOMINIO/" 2>/dev/null)"; then
  passar "HTTP do Apache funciona pelo nome app.$DOMINIO"
  for texto in 'Bruno Anderson' 'Guilherme Matias' '20251380012' '20251380014'; do
    if grep -Fq "$texto" <<<"$html"; then passar "Apache contem: $texto"; else falhar "Apache nao contem: $texto"; fi
  done
else
  falhar 'Nao foi possivel obter a pagina web do Apache pelo FQDN'
fi
teste 'Firefox ESR e xauth instalados no cli' remoto cli guilherme 'command -v firefox-esr && command -v xauth'
teste 'Servidor SSH do cli habilita X11' remoto cli guilherme "sudo -n sshd -T | grep -qx 'x11forwarding yes'"
if [[ -z "${DISPLAY:-}" ]]; then
  aviso 'DISPLAY nao definido: teste grafico do Firefox via ssh -X precisa ser feito em uma sessao grafica do Debian.'
else
  if remoto cli guilherme 'true'; then
    aviso 'DISPLAY existe; confira manualmente o Firefox via ssh -X (nao o abrimos automaticamente).'
  fi
fi
printf '\nRESUMO: %d OK | %d FALHAS | %d AVISOS\nRelatorio: %s\n' "$PASSOU" "$FALHOU" "$AVISO" "$LOG"
if (( FALHOU > 0 )); then exit 1; fi
exit 0
