# -*- mode: ruby -*-
# vi: set ft=ruby :

# Para executar no LibVirt sem precisar de senha de root:
# - sudo usermod -a -G libvirt $(whoami)
# - sudo usermod -a -G kvm $(whoami)
# - sudo usermod -a -G libvirt-qemu $(whoami)

ENV["VAGRANT_DEFAULT_PROVIDER"] = "libvirt"

# Definição dos nodes com seus IPs e recursos
nodes = {
  "haproxy1" \
    => { "ip" => "172.28.0.11", "memory" => 512, "cpus" => 1 },
  "memcached1" \
    => { "ip" => "172.28.0.12", "memory" => 512, "cpus" => 1 },
  "mariadb1" \
    => { "ip" => "172.28.0.13", "memory" => 2048, "cpus" => 2 },
  "glpi1" \
    => { "ip" => "172.28.0.14", "memory" => 2048, "cpus" => 2 },
  "monitoramento1" \
    => { "ip" => "172.28.0.15", "memory" => 2048, "cpus" => 1, "as" => false }
}

Vagrant.configure("2") do |config|
  # Gera a chave SSH se não existir
  unless File.exist?('id_ed25519') && File.exist?('id_ed25519.pub')
    system('ssh-keygen -t ed25519 -f id_ed25519 -N "" >/dev/null 2>&1')
    puts "Nova chave SSH gerada."
  end

  # Remove as chaves após destruir todas as VMs
  config.trigger.after :destroy do |trigger|
    trigger.ruby do |env, machine|
      if File.exist?('id_ed25519')
        File.delete('id_ed25519')
        File.delete('id_ed25519.pub')
        puts "Chave SSH removida."
      end
    end
  end

  # Imagem a ser utilizada
  config.vm.box = "debian/bookworm64"
  config.vm.post_up_message = ""
  config.ssh.insert_key = false
  config.vm.synced_folder "./", "/vagrant", type: "virtiofs"

  # Configuração comum para todas as VMs (LibVirt)
  config.vm.provider :libvirt do |libvirt|
    libvirt.driver = "kvm"
    libvirt.memorybacking :source, :type => "memfd"
    libvirt.memorybacking :access, :mode => "shared"

    libvirt.cpu_mode = "host-model"
    libvirt.nested = true

    libvirt.nic_model_type = "virtio"
  end

  nodes.each do |node_name, specs|
    config.vm.define node_name, autostart: ENV['MON'] ? true : specs.fetch("as", true) do |node|
      node.vm.hostname = node_name
      node.vm.network "private_network", ip: specs["ip"]

      # Sobrescreve as configurações de memória e CPU para cada VM
      node.vm.provider :libvirt do |libvirt|
        libvirt.memory = specs["memory"]
        libvirt.cpus = specs["cpus"]
      end

      # Adiciona a chave pública se ela não existir
      node.vm.provision "shell" do |s|
        s.inline = <<-SHELL
          PUBKEY=$(cat /vagrant/id_ed25519.pub)
          if ! grep -q "$PUBKEY" /home/vagrant/.ssh/authorized_keys; then
            echo "$PUBKEY" >> /home/vagrant/.ssh/authorized_keys
            echo "Chave SSH adicionada."
          else
            echo "A chave SSH já existe no arquivo authorized_keys."
          fi
        SHELL
      end
    end
  end
end
