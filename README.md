# Projeto 01 — ASA / Vagrant + Ansible

**Equipe:** Bruno Anderson — matrícula 20251380012; Guilherme Matias — matrícula 20251380014.  
**Disciplina:** Administração de Sistemas Abertos (IFPB, 2026.2). **Professor:** Leonidas Lima.

Implementação própria baseada no roteiro do professor. **Não inclui código da equipe de referência.**

## Como executar no Debian

Instale previamente VirtualBox, Vagrant, Ansible, Python 3 e OpenSSH. Entre na raiz desta pasta e execute:

```bash
vagrant up
```

O Vagrant prepara as chaves SSH **automaticamente** em `keys/bruno` e `keys/guilherme`,
usa o Ansible para configurar as quatro máquinas e instala **somente as chaves públicas**
no `/home/USUARIO/.ssh/authorized_keys` de cada VM. As chaves privadas permanecem no hospedeiro e `keys/` está no `.gitignore`.

O arquivo `~/.ssh/config` contém apenas aliases `asa-*` para uso diário e **não** adiciona chaves
implicitamente aos nomes `arq.bruno.guilherme.devops`, etc.; isso é importante para o teste de
bloqueio de login sem `-i` realizado pelo avaliador do professor.

### Máquinas

| Máquina | IP | Serviço |
|---|---|---|
| arq | 192.168.56.112 (fixo) | DHCP, Bind9 DNS, LVM, NFS |
| db | 192.168.56.114 (reserva DHCP) | MariaDB, autofs |
| app | 192.168.56.124 (reserva DHCP) | Apache2, autofs |
| cli | 192.168.56.50 (concessão DHCP dinâmica esperada) | Firefox ESR, xauth, autofs |

**Domínio:** `bruno.guilherme.devops`. Servidor DHCP autoritativo: faixa `.50` a `.100`,
lease padrão 180 s, máximo 3600 s, gateway `.1`, servidor DNS `.112`.

**Atenção:** a faixa DHCP não obriga o servidor a entregar exatamente `.50`. O provisionamento
verifica que o `cli` obteve `.50` e para com erro se ele recebeu outro endereço. Se isso acontecer,
precisamos verificar os leases do servidor, sem transformar o cliente em uma reserva fixa contrária
ao roteiro.

## O teste do professor

O script `verifica-proj1.py` espera ser executado **na raiz do projeto**, assim:

```bash
./verifica-proj1.py bruno.guilherme
```

Ele procura as chaves locais `keys/bruno` e `keys/guilherme` **sem extensão**. Não coloque essas
chaves em um repositório público. O teste cria temporariamente o usuário `intruso` nas VMs para
verificar o SSH; execute-o apenas nas VMs que você controla.

### DNS do hospedeiro e entrada /etc/hosts

`arq`, `db` e `app` devem resolver pelo servidor DNS, **não** por entradas no `/etc/hosts`.
O trigger `scripts/configurar-dns-host.sh` tenta configurar o domínio ASA via `resolvectl`
quando disponível. Caso sua distribuição use outra configuração DNS, será necessário conferir
o resolver da máquina real sem adicionar esses três IPs ao `/etc/hosts`.

**Somente o cliente** deve constar manualmente em `/etc/hosts` para a apresentação:

```text
192.168.56.50 cli.bruno.guilherme.devops cli
```

O `cli` precisa realmente ter recebido `.50` antes de adicionar essa linha.

### Serviços e critérios do roteiro

* Arq: três discos adicionais de 10 GB; VG `dados`, LV `ifpb` de 15 GB,
  ext4 montado em `/dados`; compartilhamento NFS `/dados/nfs` (all_squash, sync e usuário `nfs-ifpb`).
* `db` usa MariaDB e autofs em `/var/nfs`; `app` usa Apache e autofs; `cli` usa
  Firefox ESR, `xauth`, X11 SSH e autofs.
* Todas as VMs: Debian Bookworm, chrony (`pool.ntp.br`), fuso `America/Recife`,
  usuários `bruno` e `guilherme` no grupo `ifpb`, sudo autorizado, SSH com chave pública e sem root.
* `ansible.cfg` e `inventory/hosts` são arquivos para verificações manuais posteriores.
  O `vagrant up` usa o inventário dinâmico gerado pelo Vagrant para o primeiro provisionamento.

## Verificações rápidas

```bash
vagrant status
vagrant ssh arq -c 'sudo pvs; sudo lvs dados/ifpb'
vagrant ssh arq -c 'sudo systemctl status isc-dhcp-server bind9 nfs-kernel-server --no-pager'
vagrant ssh db -c 'ip -4 addr'
vagrant ssh app -c 'ip -4 addr'
vagrant ssh cli -c 'ip -4 addr'
ssh bruno@arq.bruno.guilherme.devops -i keys/bruno sudo id bruno
ssh guilherme@arq.bruno.guilherme.devops -i keys/guilherme sudo id guilherme
```

**Importante:** a sintaxe estática pode ser validada fora de uma VM, mas o funcionamento de
`vagrant up`/VirtualBox, das concessões DHCP e do script oficial deve ser confirmado na
máquina Debian do grupo. Este material não afirma aprovação automática.

## Fechamento e apresentação

- **[APRESENTACAO-E-TESTES.md](APRESENTACAO-E-TESTES.md)** descreve a ordem da demonstração, os testes visuais e os critérios do roteiro.
- `./scripts/verificar-entrega.sh` é uma verificação extra **sem alteração nas VMs**, com relatório salvo em `relatorios/`. Ela não substitui o avaliador oficial.
- A saída bem-sucedida do avaliador enviada em 20/11/2026 foi obtida nas VMs do grupo. A criação **do zero** com um único `vagrant up` ainda precisa ser demonstrada em um ambiente limpo; não destrua as máquinas que já passaram.
