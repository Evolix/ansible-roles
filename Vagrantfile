# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "debian/jessie64"

  config.vm.synced_folder "./vagrant_share/", "/vagrant", disabled: true

  config.vm.provider :virtualbox do |v|
    v.memory = 1024
    v.cpus = 2
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--ioapic", "on"]
  end

  # Master
  config.vm.define :default do |default|
    default.vm.hostname = "default"
    default.vm.network :private_network, ip: "192.168.33.33"
    default.vm.provision :ansible do |ansible|
          ansible.limit = "default"
          ansible.playbook = "vagrant.yml"
          # ansible.tags = "mysql"
          ansible.raw_arguments = ["-b"]
    end
  end

end
