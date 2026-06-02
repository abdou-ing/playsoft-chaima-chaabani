
data "aws_availability_zones" "available" {}

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
}

locals {
  s3_backup_bucket_name = var.create_s3_backup_bucket ? aws_s3_bucket.backup[0].bucket : var.s3_backup_bucket_name
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb"
  description = "ALB access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "jump" {
  name        = "${var.project_name}-jump"
  description = "JumpServer nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "data" {
  name        = "${var.project_name}-data"
  description = "PostgreSQL and Redis"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.jump.id]
  }

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.jump.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "backup" {
  count  = var.create_s3_backup_bucket ? 1 : 0
  bucket = var.s3_backup_bucket_name

  tags = {
    Name = "${var.project_name}-backup"
  }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  count  = var.create_s3_backup_bucket ? 1 : 0
  bucket = aws_s3_bucket.backup[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "backup" {
  count  = var.create_s3_backup_bucket ? 1 : 0
  bucket = aws_s3_bucket.backup[0].id

  versioning_configuration {
    status = "Enabled"
  }
}



resource "aws_iam_role" "jump" {
  count = var.create_iam_role ? 1 : 0
  name  = var.iam_role_name != "" ? var.iam_role_name : "${var.project_name}-ec2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jump" {
  count = var.create_iam_role ? 1 : 0
  name  = "${var.project_name}-instance-profile"
  role  = aws_iam_role.jump[0].name
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.create_iam_role && var.attach_ssm_policy ? 1 : 0
  role       = aws_iam_role.jump[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  count      = var.create_iam_role && var.attach_cloudwatch_policy ? 1 : 0
  role       = aws_iam_role.jump[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_policy" "s3_backup" {
  count = var.create_iam_role && var.enable_s3_backup ? 1 : 0
  name  = "${var.project_name}-s3-backup"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${local.s3_backup_bucket_name}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${local.s3_backup_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_backup" {
  count      = var.create_iam_role && var.enable_s3_backup ? 1 : 0
  role       = aws_iam_role.jump[0].name
  policy_arn = aws_iam_policy.s3_backup[0].arn
}

resource "aws_instance" "data" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.data_instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.data.id]
  key_name                    = var.aws_key_name
  associate_public_ip_address = true
  iam_instance_profile        = var.create_iam_role ? aws_iam_instance_profile.jump[0].name : null

  root_block_device {
    volume_size = var.data_volume_size_gb
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/cloud-init-data.yml.tftpl", {
    db_name                = var.postgres_db
    db_user                = var.postgres_user
    db_password            = var.postgres_password
    redis_password         = var.redis_password
    allowed_net            = var.vpc_cidr
    storagebox_user        = var.storagebox_user
    storagebox_password    = var.storagebox_password
    storagebox_host        = var.storagebox_host
    storagebox_remote_path = var.storagebox_remote_path
    s3_backup_bucket       = local.s3_backup_bucket_name
    s3_backup_prefix       = var.s3_backup_prefix
    s3_backup_region       = var.aws_region
    s3_backup_cron         = var.s3_backup_cron
    enable_s3_backup       = var.enable_s3_backup
  })

  tags = {
    Name = "${var.project_name}-data"
  }
}

resource "aws_instance" "jump" {
  count                       = var.jump_node_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.jump_instance_type
  subnet_id                   = aws_subnet.public[count.index % length(aws_subnet.public)].id
  vpc_security_group_ids      = [aws_security_group.jump.id]
  key_name                    = var.aws_key_name
  associate_public_ip_address = true
  iam_instance_profile        = var.create_iam_role ? aws_iam_instance_profile.jump[0].name : null

  root_block_device {
    volume_size = var.jump_volume_size_gb
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/cloud-init-jumpserver.yml.tftpl", {
    node_name      = "jump-realtime-${count.index + 1}"
    db_host        = aws_instance.data.private_ip
    db_port        = 5432
    db_name        = var.postgres_db
    db_user        = var.postgres_user
    db_password    = var.postgres_password
    redis_host     = aws_instance.data.private_ip
    redis_port     = 6379
    redis_password = var.redis_password
  })

  tags = {
    Name = "${var.project_name}-app-${count.index + 1}"
  }

  depends_on = [aws_instance.data]
}

resource "aws_lb" "jump" {
  name               = "${var.project_name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for s in aws_subnet.public : s.id]

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "jump" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  stickiness {
    type            = "lb_cookie"
    enabled         = true
    cookie_duration = 3600
  }
  health_check {
    path                = "/"
    interval            = 15
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.jump.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jump.arn
  }
}

resource "aws_lb_target_group_attachment" "jump" {
  count            = var.jump_node_count
  target_group_arn = aws_lb_target_group.jump.arn
  target_id        = aws_instance.jump[count.index].id
  port             = 80
}

resource "aws_route53_record" "jump" {
  count   = var.create_dns_record ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.dns_record_name
  type    = "A"

  alias {
    name                   = aws_lb.jump.dns_name
    zone_id                = aws_lb.jump.zone_id
    evaluate_target_health = false
  }
}
