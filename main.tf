terraform {
  required_providers {
    yandex = {
        source = "yandex-cloud/yandex"
    }
  }

    required_version = ">= 0.13"
}

provider "yandex" {
  zone = "ru-central1-d"
}

data "yandex_compute_image" "my_image" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "vm" {
  count = 2
  name = "vm-${count.index}"
  platform_id = "standard-v3"

  scheduling_policy {
    preemptible = true
  }

  boot_disk { 
    initialize_params{
        image_id = data.yandex_compute_image.my_image.id
        size = 10
    }
  }

  resources {
    cores = 2
    memory = 2
    core_fraction = 20
  }

  metadata = {
    ssh-keys = "debian:${file("~/.ssh/ssh-key-1788708402110.pub")}"
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1.id
    nat = true
  }
}

resource "yandex_vpc_network" "network" {
    name = "network"
}

resource "yandex_vpc_subnet" "subnet1" {
  name = "subnet1"
  v4_cidr_blocks = ["10.2.1.0/24"]
  network_id = yandex_vpc_network.network.id
  zone = "ru-central1-d"
}

resource "yandex_lb_target_group" "group1" {
   name = "group1"
   dynamic "target" {
     for_each = yandex_compute_instance.vm
     content {
      subnet_id = yandex_vpc_subnet.subnet1.id
      address = target.value.network_interface.0.ip_address
     }
   }
}

resource "yandex_lb_network_load_balancer" "balancer1" {
  name = "balancer1"

  listener {
    name = "my-listener1"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.group1.id

    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}
