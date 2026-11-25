###############################################################################
# KubeShop (Zibiska Korp) - infraestrutura na AWS
#
#   Internet --80/443--> [VM app: Caddy -> Nginx/React -> API]  (IP elástico)
#                                   |
#                                   | 27017 (rede privada da VPC)
#                                   v
#                        [VM db: MongoDB + volume EBS de dados]
#
# A porta do MongoDB só aceita conexões vindas do security group da VM app.
###############################################################################

data "aws_availability_zones" "available" {
  state = "available"
}

# Ubuntu Server 24.04 LTS (Canonical). A AMI é resolvida na criação; novas
# AMIs publicadas depois não recriam as VMs (ver ignore_changes abaixo). As
# atualizações do sistema são aplicadas pelo Ansible (update_os=true).
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  az          = var.availability_zone != "" ? var.availability_zone : data.aws_availability_zones.available.names[0]
  name_prefix = "${var.instance_name}-${var.environment}"
  # Nomes "técnicos" (SG, IAM, key pair) não dependem de instance_name:
  # renomear a VM não pode forçar a recriação desses recursos.
  stack = "kubeshop-${var.environment}"
}

# --------------------------------------------------------------------------
# Rede
# --------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.stack}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.stack}-igw" }
}

resource "aws_subnet" "app" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.app_subnet_cidr
  availability_zone = local.az

  tags = { Name = "${local.stack}-app", Tier = "app" }
}

resource "aws_subnet" "db" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnet_cidr
  availability_zone = local.az

  tags = { Name = "${local.stack}-db", Tier = "db" }
}

# As duas sub-redes saem para a internet pelo internet gateway (atualizações
# do SO e download de imagens). Não usamos NAT Gateway por custo (~US$ 33/mês);
# a VM do banco tem IP público apenas para saída e nenhuma porta de entrada
# aberta para a internet (ver security group "db").
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.stack}-rt" }
}

resource "aws_route_table_association" "app" {
  subnet_id      = aws_subnet.app.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "db" {
  subnet_id      = aws_subnet.db.id
  route_table_id = aws_route_table.public.id
}

# --------------------------------------------------------------------------
# Regras de acesso (security groups)
# Regras em recursos separados: a pipeline pode abrir a porta 22 para o IP do
# runner durante a execução sem gerar diferença no Terraform.
# --------------------------------------------------------------------------

resource "aws_security_group" "app" {
  name        = "${local.stack}-app"
  description = "VM da aplicacao: HTTP/HTTPS publico; SSH restrito"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.stack}-app" }
}

resource "aws_security_group" "db" {
  name        = "${local.stack}-db"
  description = "VM do MongoDB: 27017 e SSH somente a partir da VM da aplicacao"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.stack}-db" }
}

resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP publico (Caddy)"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS publico (Caddy)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh_admin" {
  for_each = toset(var.admin_cidrs)

  security_group_id = aws_security_group.app.id
  description       = "SSH de administracao (IP fixo autorizado)"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Saida liberada (atualizacoes, imagens e MongoDB)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "db_mongo_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "MongoDB somente a partir da VM da aplicacao"
  ip_protocol                  = "tcp"
  from_port                    = 27017
  to_port                      = 27017
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "db_ssh_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "SSH administrativo via VM da aplicacao (bastion)"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "db_all" {
  security_group_id = aws_security_group.db.id
  description       = "Saida liberada (atualizacoes, imagens e backups no S3)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --------------------------------------------------------------------------
# Acesso administrativo: chave SSH e perfis IAM das VMs
# --------------------------------------------------------------------------

resource "aws_key_pair" "admin" {
  key_name   = local.stack
  public_key = var.ssh_public_key
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${local.stack}-app"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role" "db" {
  name               = "${local.stack}-db"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Session Manager: acesso de emergência ao terminal das VMs pelo console da
# AWS, sem abrir portas.
resource "aws_iam_role_policy_attachment" "app_ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "db_ssm" {
  role       = aws_iam_role.db.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# A VM do banco grava e lê backups somente no prefixo do próprio ambiente.
data "aws_iam_policy_document" "db_backups" {
  statement {
    sid       = "ObjetosDeBackup"
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["arn:aws:s3:::${var.backup_bucket}/backups/${var.environment}/*"]
  }

  statement {
    sid       = "ListarBackups"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.backup_bucket}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["backups/${var.environment}/*"]
    }
  }
}

resource "aws_iam_role_policy" "db_backups" {
  name   = "backups-s3"
  role   = aws_iam_role.db.id
  policy = data.aws_iam_policy_document.db_backups.json
}

resource "aws_iam_instance_profile" "app" {
  name = "${local.stack}-app"
  role = aws_iam_role.app.name
}

resource "aws_iam_instance_profile" "db" {
  name = "${local.stack}-db"
  role = aws_iam_role.db.name
}

# --------------------------------------------------------------------------
# Máquinas virtuais
# --------------------------------------------------------------------------

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.app.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.admin.key_name
  iam_instance_profile   = aws_iam_instance_profile.app.name

  # Créditos "standard": a VM não gera cobrança extra por uso de CPU acima
  # da linha de base (o padrão das t3 é "unlimited").
  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "${local.name_prefix}-app", Role = "app" }

  lifecycle {
    ignore_changes = [ami]
  }
}

# IP público fixo da loja: não muda quando a VM é parada/redimensionada.
resource "aws_eip" "app" {
  domain   = "vpc"
  instance = aws_instance.app.id

  tags = { Name = "${local.stack}-app" }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_instance" "db" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.db_instance_type
  subnet_id                   = aws_subnet.db.id
  private_ip                  = var.db_private_ip
  associate_public_ip_address = true # somente saída; nenhuma porta pública de entrada
  vpc_security_group_ids      = [aws_security_group.db.id]
  key_name                    = aws_key_pair.admin.key_name
  iam_instance_profile        = aws_iam_instance_profile.db.name

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  tags = { Name = "${local.name_prefix}-db", Role = "db" }

  lifecycle {
    ignore_changes = [ami]
  }
}

# Dados do MongoDB em volume próprio: sobrevivem a stop/start, troca de tipo
# e até à recriação da VM do banco.
resource "aws_ebs_volume" "mongo_data" {
  availability_zone = local.az
  size              = var.data_volume_size
  type              = "gp3"
  encrypted         = true

  tags = { Name = "${local.stack}-mongo-data", Role = "db-data" }
}

resource "aws_volume_attachment" "mongo_data" {
  device_name                    = "/dev/sdf"
  volume_id                      = aws_ebs_volume.mongo_data.id
  instance_id                    = aws_instance.db.id
  stop_instance_before_detaching = true
}
