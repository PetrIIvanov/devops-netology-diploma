locals {
	web_instance_name_map = {
		stage = "stage"
		prod = "prod"
	}
	instances = {
	"nginx" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"_nginx"),2,2,true]
	"mysql_m" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"_mysql_m"),4,4,false]
        "mysql_s" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"_mysql_s"),4,4,false]
        "wp" : [format("%s%s",local.web_instance_name_map[terraform.workspace],"_mysql_s"),4,4,false]
	}
	
}


resource "yandex_compute_instance" "vm-work" {

  for_each = local.instances
  name = each.value[0]

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
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
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


