locals {
	web_instance_name_map = {
		stage = "stage"
		prod = "prod"
	}
	instances = {
	"nginx" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"-nginx"),2,2,true, "petrivanov.ru","ansible"]
        "test" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"-test"),2,2,true, "test.petrivanov.ru","n/a"]
//	"mysql-m" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"-mysql-m"),4,4,false,"db01.petrivanov.ru","n/a"]
//        "mysql-s" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"-mysql-s"),4,4,false,"db02.petrivanov.ru","n/a"]
//        "wp" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"-wp"),4,4,false,"app.petrivanov.ru","n/a"]
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
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-1.id
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
      "sudo apt install git -y"

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
/*
  provisioner "remote-exec" {
    inline = [
       "mkdir ~/.ssh"
    ]
  }
*/

provisioner "file" {
  source      = "~/.ssh/id_rsa"
  destination = "/home/vagrant/.ssh/id_rsa"
}

  provisioner "remote-exec" {
/*
    connection {
      host        = yandex_compute_instance.vm-work[each.key].network_interface.0.nat_ip_address
      user        = "vagrant"
      type        = "ssh"
      private_key = "${file("~/.ssh/id_rsa")}"
      timeout     = "2m"
    }*/

    inline = [
      "sudo apt update -y",
      (each.value[5] != "ansible" ? "": "sudo apt install ansible -y"),
      "sudo apt install git -y"

    ]
  }
  
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


