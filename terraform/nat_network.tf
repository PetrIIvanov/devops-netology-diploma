# Nat setup 
locals {
  nat_instance_image_id  = "fd82fnsvr0bgt1fid7cl" # An image ID for a NAT instance. See https://cloud.yandex.ru/marketplace/products/yc/nat-instance-ubuntu-18-04-lts for details.
  cidr_internet          = "0.0.0.0/0"            # All IPv4 addresses.
  data_proc_sa_name      = "natserviceacc"                     # Set name for the service account for the Data Proc cluster.
}


resource "yandex_vpc_subnet" "subnet-nat" {
  description    = "Subnet for the NAT instance"
  name           = "subnet-nat"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network-1.id
  v4_cidr_blocks = ["192.168.20.0/24"]
}

resource "yandex_vpc_security_group" "sg-internet" {
  description = "Allow any outgoing traffic to the Internet"
  name        = "sg-internet"
  network_id  = yandex_vpc_network.network-1.id

  egress {
    description    = "Allow any outgoing traffic to the Internet"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = [local.cidr_internet]
  }
}

resource "yandex_vpc_security_group" "sg-data-proc-cluster" {
  description = "Security group for the Yandex Data Proc cluster"
  name        = "sg-data-proc-cluster"
  network_id  = yandex_vpc_network.network-1.id

  ingress {
    description       = "Allow any traffic within one security group"
    protocol          = "ANY"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }
}


resource "yandex_vpc_security_group" "sg-nat-instance" {
  description = "Security group for the NAT instance"
  name        = "sg-nat-instance"
  network_id  = yandex_vpc_network.network-1.id

  ingress {
    description    = "Allow any outgoing traffic from the Yandex Data Proc cluster"
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = [local.cidr_internet]
  }

  ingress {
    description    = "Allow SSH connections to the NAT instance"
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [local.cidr_internet]
  }

  ingress {
    description       = "Allow connections from the Data Proc cluster"
    protocol          = "ANY"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }
}

resource "yandex_iam_service_account" "dataproc-sa" {
  description = "Service account for the Yandex Data Proc cluster"
  name        = local.data_proc_sa_name
}

resource "yandex_resourcemanager_folder_iam_binding" "dataproc-sa-role-dataproc-agent" {
  # Bind role `mdb.dataproc.agent` to the service account. Required for creation of Data Proc cluster.
  folder_id = var.folder_id
  role      = "mdb.dataproc.agent"
  members = [
    "serviceAccount:${yandex_iam_service_account.dataproc-sa.id}"
  ]
}

resource "yandex_compute_instance" "nat-instance-vm" {
  description = "NAT instance VM"
  name        = "nat-instance-vm"
  platform_id = "standard-v3" # Intel Ice Lake
  #zone        = "ru-central1-b"

  resources {
    cores  = 2 # vCPU
    memory = 4 # GB
  }

  boot_disk {
    initialize_params {
      image_id = local.nat_instance_image_id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet-nat.id
    nat       = true # Required for connection from the Internet.

    security_group_ids = [
      yandex_vpc_security_group.sg-internet.id,    # Allow any outgoing traffic to Internet.
      yandex_vpc_security_group.sg-nat-instance.id # Allow connections to and from the Data Proc cluster.
    ]
  }
  metadata = {
    // ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    user-data = "${file("./userdata/meta.txt")}"
  }
}

resource "yandex_vpc_route_table" "route-table-nat" {
  description = "Route table for Data Proc cluster subnet" # All requests can be forwarded to the NAT instance IP address.
  name        = "route-table-nat"

  depends_on = [
    yandex_compute_instance.nat-instance-vm
  ]

  network_id = yandex_vpc_network.network-1.id

  static_route {
    destination_prefix = local.cidr_internet
    next_hop_address   = yandex_compute_instance.nat-instance-vm.network_interface.0.ip_address
  }
}

