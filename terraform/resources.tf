locals {
	web_instance_name_map = {
		stage = "stage"
		prod = "prod"
	}
	instances = {
	"nginx" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"-nginx"),2,2,true, "petrivanov.ru","ansible","192.168.10.5"]
        "test" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"-test"),2,2,true, "test.petrivanov.ru","n/a","192.168.10.10"]
	"mysql-m" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"-mysql-m"),4,4,true,"db01.petrivanov.ru","n/a","192.168.10.20"]
        "mysql-s" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"-mysql-s"),4,4,true,"db02.petrivanov.ru","n/a","192.168.10.21"]
        "wp" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"-wp"),4,4,true,"app.petrivanov.ru","n/a","192.168.10.30"]
        "gitlab" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"-gitlab"),4,4,true,"gitlab.petrivanov.ru","n/a","192.168.10.40"]
        "runner" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"-runner"),4,4,true,"runner.petrivanov.ru","n/a","192.168.10.41"]
        "monitoring" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"-monitoring"),4,4,true,"monitoring.petrivanov.ru","n/a","192.168.10.50"]
        }
	
}


resource "yandex_compute_instance" "vm-work" {

  for_each = local.instances
  name = each.value[0]
  hostname = each.value[4]

  resources {
    cores  = each.value[1]
    memory = each.value[2]
  }

  boot_disk {
    initialize_params {
      image_id =  "fd8kdq6d0p8sij7h5qe3" // Ubuntu 20.04
      //"fd87va5cc00gaq2f5qfb"
      size = (each.value[5] != "gitlab" ? 5 : 15 )
    }
  }

  network_interface  {
    subnet_id = yandex_vpc_subnet.subnet-1.id
    ip_address = each.value[6]
    nat       = each.value[3]
  }

  metadata = {
    // ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    user-data = "${file("./userdata/meta.txt")}"
  }

/*
  provisioner "remote-exec" {

    connection {
      host        = "${self.network_interface.0.nat_ip_address}"
      user        = "vagrant"
      type        = "ssh"
      private_key = "${file("~/.ssh/id_rsa")}"
      timeout     = "2m"
    }
    inline = [
      "sudo apt update -y",
      (each.value[5] != "ansible" ? "": "sudo apt install ansible -y"),
      "sudo apt install git -y",
      "git clone https://github.com/PetrIIvanov/ansible-nginx-revproxy.git /home/vagrant/provision"

    ]
  }
*/
}

resource "null_resource" "nginx_ansible" {
  for_each = {
    for k, v in local.instances : k => v
    if k == "nginx"
  }

    connection {
      host        = yandex_compute_instance.vm-work[each.key].network_interface.0.nat_ip_address
      user        = "vagrant"
      type        = "ssh"
      private_key = "${file("~/.ssh/id_rsa")}"
      timeout     = "2m"
    }
provisioner "remote-exec" {
   inline = [
       "mkdir -p /home/vagrant/provision",
       "mkdir -p /home/vagrant/hosts"
   ]
  }
provisioner "file" {
  source      = "${path.root}/../ansible/"
  destination = "/home/vagrant/provision"
}

provisioner "file" {
  source      = "${path.root}/../hosts/hosts"
  destination = "/home/vagrant/hosts/hosts"
}

provisioner "file" {
  source      = "~/.ssh/id_rsa"
  destination = "/home/vagrant/.ssh/id_rsa"
}

provisioner "remote-exec" {
  inline = [
      "sudo apt update -y",
      "sudo apt install net-tools,uzip -y",
      "sudo chmod 400 /home/vagrant/.ssh/id_rsa",
      (each.value[5] != "ansible" ? "": "sudo apt install ansible -y"),
      "sudo apt install git -y",
      "sudo bash -c 'cat  /home/vagrant/hosts/hosts >> /etc/hosts'",
      "sudo bash -c 'cat  /home/vagrant/hosts/hosts >> /etc/cloud/templates/hosts.debian.tmpl'",
      "git clone https://github.com/PetrIIvanov/ansible-nginx-revproxy.git /home/vagrant/provision/ansible-nginx-revproxy/",
      "git clone https://github.com/PetrIIvanov/ansible-role-mysql.git /home/vagrant/provision/ansible-role-mysql/",
      "git clone https://github.com/PetrIIvanov/ansible-wordpress.git /home/vagrant/provision/ansible-wordpress/",
      "git clone https://github.com/PetrIIvanov/ansible-role-monitoring /home/vagrant/provision/ansible-role-monitoring/",
      "git clone https://github.com/PetrIIvanov/ansible-alertmanager.git /home/vagrant/provision/ansible-alertmanager/",
      "git clone https://github.com/PetrIIvanov/ansible-role-gitlab.git",
      "ansible-galaxy collection install community.mysql"

    ]
  }

depends_on = [local_file.ansible_inventory, local_file.hosts
]
}

resource "yandex_vpc_network" "network-1" {
  name = "network1"
}

resource "yandex_vpc_subnet" "subnet-1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

/*
resource "yandex_vpc_subnet" "subnet-2" {
  name           = "subnet2"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.20.0/24"]
}
*/

resource "local_file" "ansible_inventory" {

  content = templatefile("${path.root}/templates/inventory.tpl", {
    nodes = [
      for k,v in local.instances:
      [k, yandex_compute_instance.vm-work[k].network_interface.0.ip_address]
    ]
  })
  filename  = "${path.root}/../ansible/inventory"
  file_permission = 644 
}

resource "local_file" "hosts" {

  content = templatefile("${path.root}/templates/hosts.tpl", {
    nodes = [
      for k,v in local.instances:
      [v[4], yandex_compute_instance.vm-work[k].network_interface.0.ip_address]
    ]
  })
  filename  = "${path.root}/../hosts/hosts"
  file_permission = 644
}

 output "internal_ip_address_vm_work" {
  value = { 
for k,v in local.instances:
k => yandex_compute_instance.vm-work[k].network_interface.0.ip_address }
}


output "external_ip_address_vm_work" {
  value = {
for k,v in local.instances:
k => yandex_compute_instance.vm-work[k].network_interface.0.nat_ip_address

}

}


