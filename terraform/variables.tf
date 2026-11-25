variable "environment" {
  description = "Ambiente de destino (dev, homolog ou prod)."
  type        = string

  validation {
    condition     = contains(["dev", "homolog", "prod"], var.environment)
    error_message = "environment deve ser dev, homolog ou prod."
  }
}

variable "aws_region" {
  description = "Região da AWS."
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Zona de disponibilidade. Vazio = primeira zona disponível da região."
  type        = string
  default     = ""
}

variable "instance_name" {
  description = "Nome base das VMs. Resultado: <instance_name>-<ambiente>-app e <instance_name>-<ambiente>-db. Muda só a tag Name (sem recriar)."
  type        = string
  default     = "vm-pm04"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}$", var.instance_name))
    error_message = "instance_name: use 2 a 31 caracteres minúsculos, números ou hífen."
  }
}

variable "instance_type" {
  description = "Tipo da VM da aplicação (Nginx/React + API). Alterar faz stop/start, sem recriar."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "instance_type deve ser t3.micro ou t3.small (tipos do plano gratuito da AWS)."
  }
}

variable "db_instance_type" {
  description = "Tipo da VM exclusiva do MongoDB. Alterar faz stop/start, sem recriar e sem perder dados."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small"], var.db_instance_type)
    error_message = "db_instance_type deve ser t3.micro ou t3.small (tipos do plano gratuito da AWS)."
  }
}

variable "ssh_public_key" {
  description = "Chave pública SSH de administração (derivada do secret SSH_PRIVATE_KEY pela pipeline)."
  type        = string
}

variable "admin_cidrs" {
  description = "IPs fixos (CIDR) com acesso SSH à VM da aplicação. A pipeline libera o IP do runner só durante a execução."
  type        = list(string)
  default     = []
}

variable "backup_bucket" {
  description = "Bucket S3 do state e dos backups (criado por scripts/bootstrap-backend.sh)."
  type        = string
}

variable "vpc_cidr" {
  description = "Faixa de rede da VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "app_subnet_cidr" {
  description = "Sub-rede da VM da aplicação."
  type        = string
  default     = "10.20.1.0/24"
}

variable "db_subnet_cidr" {
  description = "Sub-rede da VM do banco."
  type        = string
  default     = "10.20.2.0/24"
}

variable "db_private_ip" {
  description = "IP privado fixo do MongoDB (usado pela API)."
  type        = string
  default     = "10.20.2.10"
}

variable "root_volume_size" {
  description = "Disco do sistema de cada VM (GB)."
  type        = number
  default     = 12
}

variable "data_volume_size" {
  description = "Volume EBS dedicado aos dados do MongoDB (GB)."
  type        = number
  default     = 10
}

variable "domain_name" {
  description = "Domínio da loja (opcional). Vazio = acesso por http://<IP elástico>."
  type        = string
  default     = ""
}
