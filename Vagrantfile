# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"
$init = <<SCRIPT
sudo apt-get -y update
sudo apt-get -y install python-pip
SCRIPT

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  
  config.vm.provider "virtualbox" do |v|
    v.memory = 1024
    v.cpus = 1
    v.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]
  end
  
  config.vm.define "droopy" do |v|
    v.vm.box = "ubuntu1404"
    v.vm.box_url = "https://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-i386-vagrant-disk1.box"
    v.vm.hostname = "droory"
    v.vm.network "private_network", ip: "192.168.33.80"
    v.ssh.forward_agent = true
    v.vm.provision :shell, :inline => $init
  end
  
end
