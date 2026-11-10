terraform {
  required_providers {
    cloudru = {
      source  = "cloudru/cloud"
      version = "2.1.6"
    }
  }
}

variable "project_id" {
  type        = string
  description = "Идентификатор проекта из console.cloud.ru"
  default     = "2b6c2a28-07a3-4161-a88b-c2812b1188ca" # <-- ВСТАВЬТЕ ВАШ PROJECT ID
}

variable "auth_key_id" {
  type        = string
  description = "Идентификатор ключа доступа сервисного аккаунта"
  sensitive   = true
  default     = "eaf94b722ed060d7bf1a977ed3789e2a" # <-- ВСТАВЬТЕ ВАШ AUTH KEY ID
}

variable "auth_secret" {
  type        = string
  description = "Секрет ключа доступа сервисного аккаунта"
  sensitive   = true
  default     = "d0eeba1772b3e2ccedf61a2a812254ba" # <-- ВСТАВЬТЕ ВАШ AUTH SECRET
}

variable "vpc_id" {
  type        = string
  description = "Идентификатор VPC"
  default     = "263c6cdd-a9f3-4b60-926f-d66f01edddca" # <-- ВСТАВЬТЕ ВАШ VPC ID
}

variable "my_ip_cidr" {
  type        = string
  description = "CIDR вашего IP-адреса для доступа по SSH (например 1.2.3.4/32)"
  default     = "0.0.0.0/0" # <-- ВСТАВЬТЕ ВАШ IP В ФОРМАТЕ CIDR
}

variable "vm_name" {
  type        = string
  description = "Имя виртуальной машины"
  default     = "api"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Путь к публичному SSH ключу"
  default     = "~/.ssh/id_api.pub"
}

variable "disk_size" {
  type        = number
  description = "Размер диска в ГБ"
  default     = 20
}

variable "disk_type" {
  type        = string
  description = "Тип диска"
  default     = "SSD"
}

variable "flavor" {
  type        = string
  description = "Flavor ВМ"
  default     = "gen-2-4"
}

variable "zone" {
  type        = string
  description = "Зона доступности"
  default     = "ru.AZ-1"
}

# =============================================================================
# Провайдер
# =============================================================================

provider "cloudru" {
  project_id  = var.project_id
  auth_key_id = var.auth_key_id
  auth_secret = var.auth_secret

  endpoints = {
    iam_endpoint     = "iam.api.cloud.ru:443"
    compute_endpoint = "compute.api.cloud.ru:443"
  }
}

# =============================================================================
# Data sources
# =============================================================================

data "cloudru_evolution_compute_image_collection" "ubuntu" {
  project_id = var.project_id
  page_size  = 100
}

# =============================================================================
# Конфигурация cloud-init
# =============================================================================

locals {
  cloud_config = templatefile("${path.module}/cloud-init.yaml.tpl", {
    ssh_public_key = file(var.ssh_public_key_path)
    vm_name        = var.vm_name
  })
}

# =============================================================================
# Группа безопасности
# =============================================================================

resource "cloudru_evolution_compute_security_group" "example" {
  project_id = var.project_id

  name = "tf-evo-sg"

  zone = {
    name = var.zone
  }

  description = "Группа безопасности для ВМ"
}

# =============================================================================
# Правила группы безопасности
# =============================================================================

# SSH (22) — доступ только с вашего IP
resource "cloudru_evolution_compute_security_group_rule" "ingress_ssh" {
  security_group_id = cloudru_evolution_compute_security_group.example.id
  direction         = "TRAFFIC_DIRECTION_INGRESS"
  ether_type        = "ETHER_TYPE_IPV4"
  ip_protocol       = "IP_PROTOCOL_TCP"
  port_range        = "22:22"
  description       = "SSH доступ с моего IP"
  remote_ip_prefix  = var.my_ip_cidr
}

# HTTPS (443) — доступ отовсюду
resource "cloudru_evolution_compute_security_group_rule" "ingress_https" {
  security_group_id = cloudru_evolution_compute_security_group.example.id
  direction         = "TRAFFIC_DIRECTION_INGRESS"
  ether_type        = "ETHER_TYPE_IPV4"
  ip_protocol       = "IP_PROTOCOL_TCP"
  port_range        = "443:443"
  description       = "HTTPS доступ отовсюду"
  remote_ip_prefix  = "0.0.0.0/0"
}

# Исходящий TCP
resource "cloudru_evolution_compute_security_group_rule" "egress_tcp" {
  security_group_id = cloudru_evolution_compute_security_group.example.id
  direction         = "TRAFFIC_DIRECTION_EGRESS"
  ether_type        = "ETHER_TYPE_IPV4"
  ip_protocol       = "IP_PROTOCOL_TCP"
  port_range        = "1:65535"
  description       = "Разрешить весь исходящий TCP"
  remote_ip_prefix  = "0.0.0.0/0"
}

# Исходящий UDP
resource "cloudru_evolution_compute_security_group_rule" "egress_udp" {
  security_group_id = cloudru_evolution_compute_security_group.example.id
  direction         = "TRAFFIC_DIRECTION_EGRESS"
  ether_type        = "ETHER_TYPE_IPV4"
  ip_protocol       = "IP_PROTOCOL_UDP"
  port_range        = "1:65535"
  description       = "Разрешить весь исходящий UDP"
  remote_ip_prefix  = "0.0.0.0/0"
}

# =============================================================================
# Диск
# =============================================================================

resource "cloudru_evolution_compute_disk" "example" {
  project_id = var.project_id

  name = "tf-evo-disk"
  size = var.disk_size

  zone = {
    name = var.zone
  }

  disk_type = {
    name = var.disk_type
  }

  description = "Загрузочный диск для ВМ"
  bootable    = true
  image    = {
    id = [for img in data.cloudru_evolution_compute_image_collection.ubuntu.images : img.id if img.name == "ubuntu-22.04"][0]
  }
  encrypted   = false
  readonly    = false
  shared      = false
}

# =============================================================================
# Сетевой интерфейс
# =============================================================================

resource "cloudru_evolution_compute_external_ip" "example" {
  project_id = var.project_id

  name        = "tf-evo-external-ip"
  description = "Публичный IP для API"

  zone = {
    name = var.zone
  }
}

resource "cloudru_evolution_compute_interface" "example" {
  project_id = var.project_id

  name = "tf-evo-interface"

  zone = {
    name = var.zone
  }

  description                = "Сетевой интерфейс для ВМ"
  subnet                  = {
    id = "e1706f84-76e9-4760-9cab-b081868d6fd0"
  }
  interface_security_enabled = true

  security_groups = [
    {
      id = cloudru_evolution_compute_security_group.example.id
    }
  ]

  attach_external_ip = {
    id = cloudru_evolution_compute_external_ip.example.id
  }

  type = "INTERFACE_TYPE_REGULAR"
}

# =============================================================================
# Виртуальная машина
# =============================================================================

resource "cloudru_evolution_compute_vm" "example" {
  project_id = var.project_id

  name = var.vm_name

  zone = {
    name = var.zone
  }

  flavor = {
    name = var.flavor
  }

  description = "ВМ, созданная через Terraform"

  disks = [{
    id = cloudru_evolution_compute_disk.example.id
  }]

  network_interfaces = [{
    id = cloudru_evolution_compute_interface.example.id
  }]

  cloud_init_userdata = base64encode(local.cloud_config)
}

# =============================================================================
# Вывод значений
# =============================================================================

output "vm_id" {
  description = "ID виртуальной машины"
  value       = cloudru_evolution_compute_vm.example.id
}

output "vm_name" {
  description = "Имя виртуальной машины"
  value       = cloudru_evolution_compute_vm.example.name
}

output "vm_internal_ip" {
  description = "Внутренний IP адрес"
  value       = cloudru_evolution_compute_interface.example.ip_address
}

output "external_ip" {
  description = "Внешний IP адрес"
  value       = cloudru_evolution_compute_interface.example.attach_external_ip.ip_address
}
