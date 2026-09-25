# Reference VM: stock Rocky Linux 9 with these dotfiles installed. The work VM
# has its own Vagrantfile; copy the two provision steps below into it.
#
#   vagrant up                                    # clones from GitHub
#   DOTFILES_REPO=/vagrant vagrant up             # tests this checkout's commits
#
# The work VM's own provision.sh (runs as root) needs one line:
#   curl -fsSL https://raw.githubusercontent.com/Derrekito/rocky9-dotfiles/main/provision/bootstrap.sh | bash -s -- vagrant
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

  config.vm.provision "dotfiles", type: "shell", privileged: true,
    path: "provision/bootstrap.sh", args: ["vagrant"],
    env: { "DOTFILES_REPO" => ENV.fetch("DOTFILES_REPO", "") }.reject { |_, v| v.empty? }
end
