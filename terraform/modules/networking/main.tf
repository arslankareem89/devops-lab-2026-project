resource "aws_internet_gateway" "main" {
  vpc_id = var.vpc_id

  tags = {
    Name        = "${var.name}-igw"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.name}-nat-eip"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = var.public_subnet_id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name        = "${var.name}-nat"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.name}-public-rt"
    Environment = var.environment
    Tier        = "public"
    ManagedBy   = "Terraform"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = var.public_subnet_id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "${var.name}-private-rt"
    Environment = var.environment
    Tier        = "private"
    ManagedBy   = "Terraform"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = var.private_subnet_id
  route_table_id = aws_route_table.private.id
}
