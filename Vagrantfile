
Vagrant.configure("2") do |config|
  config.vm.box = "debian/bookworm64"
  config.ssh.insert_key = false
  config.vbguest.auto_update = false if Vagrant.has_plugin?("vagrant-vbguest")

  config.trigger.before :up do |trigger|
    trigger.info = "Desabilitando servidor DHCP do VirtualBox..."
    trigger.run = {inline: "bash -c 'VBoxManage dhcpserver remove --network=HostInterfaceNetworking-vboxnet0 2>/dev/null || true'"}
  end

  config.vm.define "arq" do |arq|
    arq.vm.hostname = "arq.bruno.guilherme.devops"
    arq.vm.network "private_network", ip: "192.168.56.114"
    arq.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.linked_clone = true
      vb.check_guest_additions = false

      file_to_disk1 = "disk1.vdi"
      file_to_disk2 = "disk2.vdi"
      file_to_disk3 = "disk3.vdi"
      unless File.exist?(file_to_disk1)
        vb.customize ['createhd', '--filename', file_to_disk1, '--size', 10240]
        vb.customize ['createhd', '--filename', file_to_disk2, '--size', 10240]
        vb.customize ['createhd', '--filename', file_to_disk3, '--size', 10240]
      end
      vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', file_to_disk1]
      vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 2, '--device', 0, '--type', 'hdd', '--medium', file_to_disk2]
      vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 3, '--device', 0, '--type', 'hdd', '--medium', file_to_disk3]
    end
  end

  config.vm.define "db" do |db|
    db.vm.hostname = "db.bruno.guilherme.devops"
    db.vm.network "private_network", type: "dhcp", mac: "080027000112"
    db.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.linked_clone = true
      vb.check_guest_additions = false
    end
  end

  config.vm.define "app" do |app|
    app.vm.hostname = "app.bruno.guilherme.devops"
    app.vm.network "private_network", type: "dhcp", mac: "080027000142"
    app.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
      vb.linked_clone = true
      vb.check_guest_additions = false
    end
  end

  config.vm.define "cli" do |cli|
    cli.vm.hostname = "cli.bruno.guilherme.devops"
    cli.vm.network "private_network", type: "dhcp"
    cli.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.linked_clone = true
      vb.check_guest_additions = false
    end

    # O Ansible só deve rodar quando a última máquina (cli) estiver pronta
    cli.vm.provision "ansible" do |ansible|
      ansible.playbook = "playbook.yml"
      ansible.inventory_path = "inventory.ini"
      ansible.config_file = "ansible.cfg"
      ansible.become = true
      ansible.limit = "all"
    end
  end
end
