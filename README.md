# Projeto-01---DevOps-com-Vagrant-e-Ansible
**Disciplina:** Administração de Sistemas Abertos  
**Professor:** Leonidas Lima | **Período:** 2026.2  

**Equipe:**  
 Bruno Anderson (Matrícula: 20251380014)  
 Guilherme Matias (Matrícula: 20251380012)  

**Descrição:**  
Projeto de provisionamento de 4 máquinas virtuais Debian utilizando Vagrant. A configuração automatizada (Ansible) abrange serviços de infraestrutura de redes e sistemas, incluindo DHCP, DNS, NFS, LVM, Autofs, Apache2 e MariaDB.  
- **Rede Privada:** 192.168.56.0/24  
- **Servidor de Arquivos (arq):** IP 192.168.56.114  
- **Servidor de Banco de Dados (db):** IP 192.168.56.112 (via DHCP estático)  
- **Servidor de Aplicação (app):** IP 192.168.56.142 (via DHCP estático)  
- **Domínio:** bruno.guilherme.devops
