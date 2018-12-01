Vagrant.configure("2") do |config|
  config.vm.provider "virtualbox" do |v|
    v.memory = 4096
    v.cpus = 2
  end

  config.vm.box = "bento/centos-7"

  config.vm.synced_folder "/tmp", "/shared/work"

  config.vm.provision "shell", inline: <<-SHELL
    sudo rpm -Uvh /shared/work/chef-14.6.47-1.el7.x86_64.rpm
  SHELL

  #server
  config.vm.define "a2" do |a2|
    a2.vm.hostname = "a2"
    a2.vm.network "private_network", ip: "10.10.10.90"
  end
end

