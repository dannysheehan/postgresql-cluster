# -*- mode: ruby -*-
# vi: set ft=ruby :
# Interactive lab mirroring Molecule platforms (libvirt/KVM).
# Usage: vagrant up && ansible-playbook -i inventory/lab.yml playbooks/site.yml

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"

  {
    "pg-node-1" => "192.168.56.11",
    "pg-node-2" => "192.168.56.12"
  }.each do |name, ip|
    config.vm.define name do |node|
      node.vm.hostname = name
      node.vm.network "private_network", ip: ip
      node.vm.provider :libvirt do |lv|
        lv.memory = 2048
        lv.cpus = 2
        lv.cpu_mode = "host-passthrough"
      end
    end
  end
end
