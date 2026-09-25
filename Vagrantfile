# Reference VM: stock Rocky Linux 9 with these dotfiles installed. The work VM
# has its own Vagrantfile; copy the two provision steps below into it.
#
#   vagrant up                                    # clones from GitHub
#   DOTFILES_REPO=/vagrant vagrant up             # tests this checkout's commits
Vagrant.configure("2") do |config|
  config.vm.box = "rockylinux/9"
  config.vm.hostname = "rocky9-dev"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = 4096
    vb.cpus = 2
  end
  config.vm.provider "libvirt" do |lv|
    lv.memory = 4096
    lv.cpus = 2
  end

  config.vm.provision "packages", type: "shell", privileged: true,
    path: "provision/packages.sh"

  config.vm.provision "dotfiles", type: "shell", privileged: false,
    path: "provision/user.sh",
    env: { "DOTFILES_REPO" => ENV.fetch("DOTFILES_REPO", "") }
end
