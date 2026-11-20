#!/usr/bin/env bash
set -euo pipefail
# Executado pelo trigger do Vagrant no hospedeiro. Nunca copia chaves privadas para as VMs.
raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
chaves="$raiz/keys"
ssh_dir="$HOME/.ssh"
mkdir -p "$chaves" "$ssh_dir"
chmod 700 "$chaves" "$ssh_dir"
for usuario in bruno guilherme; do
  chave="$chaves/$usuario"
  if [[ ! -f "$chave" ]]; then
    ssh-keygen -q -t ed25519 -N '' -C "asa-${usuario}@bruno.guilherme.devops" -f "$chave"
  fi
  if [[ ! -f "$chave.pub" ]]; then
    ssh-keygen -y -f "$chave" > "$chave.pub"
  fi
  chmod 600 "$chave"
  chmod 644 "$chave.pub"
done

# Apenas aliases "asa-*": NUNCA vincular a chave ao FQDN usado pelo avaliador.
# O teste "ssh bruno@arq..." sem -i deve falhar; com -i keys/bruno deve passar.
python3 - "$ssh_dir/config" "$chaves" <<'PYSSH'
import os, pathlib, re, sys
config = pathlib.Path(sys.argv[1])
keys = pathlib.Path(sys.argv[2])
begin = '# INICIO ASA BRUNO GUILHERME (gerado pelo Vagrant)'
end = '# FIM ASA BRUNO GUILHERME'
linhas = [begin]
for usuario in ('bruno', 'guilherme'):
    for maquina, ip in (('arq', '192.168.56.112'), ('db', '192.168.56.114'), ('app', '192.168.56.124')):
        alias = f'asa-{maquina}' if usuario == 'bruno' else f'asa-{maquina}-{usuario}'
        linhas += [f'Host {alias}', f'    HostName {ip}', f'    User {usuario}',
                  f'    IdentityFile {keys / usuario}', '    IdentitiesOnly yes', '']
    alias = 'asa-cli' if usuario == 'bruno' else 'asa-cli-guilherme'
    linhas += [f'Host {alias}', '    HostName 127.0.0.1', '    Port 2284',
              f'    User {usuario}', f'    IdentityFile {keys / usuario}',
              '    IdentitiesOnly yes', '']
linhas += [end]
block = '\n'.join(linhas) + '\n'
old = config.read_text() if config.exists() else ''
pattern = re.escape(begin) + r'.*?' + re.escape(end) + r'\n?'
if begin in old:
    old = re.sub(pattern, '', old, flags=re.S)
config.write_text(old.rstrip() + ('\n\n' if old.strip() else '') + block)
os.chmod(config, 0o600)
PYSSH
printf '[ASA] Chaves preparadas em %s; atalhos asa-* atualizados.\n' "$chaves"
