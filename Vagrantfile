# Projeto ASA - implementação própria a partir do roteiro de 2026.2.
# Ordem dos integrantes: Bruno (20251380012), Guilherme (20251380014).
Vagrant.configure("2") do |config|
  config.vm.box = "debian/bookworm64"
  config.vm.box_check_update = false
  config.ssh.insert_key = false
  # Sem pastas compartilhadas: o Ansible instala as chaves públicas da pasta keys/.
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # O trigger é executado na máquina real e não pede comandos extras ao usuário.
  config.trigger.before :up do |trigger|
    trigger.name = "Preparar automaticamente as chaves SSH na maquina real"
    trigger.run = { path: "scripts/preparar-ssh-host.sh" }
  end

  estudantes = {
    "bruno" => "20251380012",
    "guilherme" => "20251380014"
  }
  dominio = "bruno.guilherme.devops"
  ip_arq = "192.168.56.1#{estudantes['bruno'][-2, 2]}"
  ip_db  = "192.168.56.1#{estudantes['guilherme'][-2, 2]}"
  ip_app = "192.168.56.1#{estudantes['bruno'][-1]}#{estudantes['guilherme'][-1]}"

  # MACs fixos: exatamente 12 caracteres hexadecimais por interface.
  macs = {
    "db"  => "080027120014",
    "app" => "080027120114",
    "cli" => "080027120214"
  }
  # Para selecionar a rede host-only, declaramos um IP de referência.
  # auto_config: false impede que o Vagrant atribua esse IP ao convidado.
  ip_referencia = "192.168.56.200"

  config.vm.define "arq" do |vm|
    vm.vm.hostname = "arq.#{dominio}"
    vm.vm.network "private_network", ip: ip_arq
    3.times do |n|
      vm.vm.disk :disk, size: "10GB", name: "asa_dados_#{n + 1}"
    end
    vm.vm.provider "virtualbox" do |vb|
      vb.name = "asa-bruno-guilherme-arq"
      vb.memory = 512
      vb.cpus = 1
      vb.linked_clone = true
      vb.check_guest_additions = false
    end
    vm.vm.provision "ansible" do |ansible|
      ansible.playbook = "ansible/site.yml"
      ansible.compatibility_mode = "2.0"
      ansible.become = true
      ansible.extra_vars = { "papel_vm" => "arq" }
    end
    # Após o servidor arq ser configurado, impede a concorrência do DHCP VBox.
    vm.trigger.after :up do |trigger|
      trigger.name = "Desativar o DHCP do VirtualBox na rede ASA"
      trigger.run = { path: "scripts/desativar-dhcp-vbox.sh" }
    end
  end

  ["db", "app", "cli"].each do |nome|
    config.vm.define nome do |vm|
      vm.vm.hostname = "#{nome}.#{dominio}"
      vm.vm.network "private_network", ip: ip_referencia, auto_config: false
      # O cliente tem IP DHCP variável; SSH pelo hospedeiro usa porta NAT fixa.
      if nome == "cli"
        vm.vm.network "forwarded_port", guest: 22, host: 2284,
          host_ip: "127.0.0.1", id: "asa-cli-ssh", auto_correct: false
      end
      vm.vm.provider "virtualbox" do |vb|
        vb.name = "asa-bruno-guilherme-#{nome}"
        vb.memory = (nome == "cli" ? 1024 : 512)
        vb.cpus = 1
        vb.linked_clone = true
        vb.check_guest_additions = false
        vb.customize ["modifyvm", :id, "--macaddress2", macs.fetch(nome)]
      end
      vm.trigger.before :up do |trigger|
        trigger.name = "Garantir que o DHCP do VirtualBox continue desligado"
        trigger.run = { path: "scripts/desativar-dhcp-vbox.sh" }
      end
      # Antes de executar o Ansible, obtém DHCP real do servidor arq.
      vm.vm.provision "shell", path: "scripts/configurar-cliente-dhcp.sh", args: [macs.fetch(nome), nome]
      vm.vm.provision "ansible" do |ansible|
        ansible.playbook = "ansible/site.yml"
        ansible.compatibility_mode = "2.0"
        ansible.become = true
        ansible.extra_vars = { "papel_vm" => nome }
      end
      if nome == "cli"
        vm.trigger.after :up do |trigger|
          trigger.name = "Configurar resolucao DNS do dominio ASA no hospedeiro"
          trigger.run = { path: "scripts/configurar-dns-host.sh" }
        end
      end
    end
  end

  config.vm.post_up_message = <<~MSG
    Ambiente ASA: arq=#{ip_arq}; db=#{ip_db}; app=#{ip_app}; cli=DHCP (50-100).
    Chaves privadas dos estudantes: ./keys/bruno e ./keys/guilherme
    Alias SSH: ssh asa-arq; ssh asa-db; ssh asa-app; ssh asa-cli
    O arquivo ~/.ssh/config (apenas aliases asa-*) e as chaves sao preparados automaticamente.
  MSG
end
