provider "aws" {
  region = "us-east-1"

  access_key = "xxxxxxxxxxxxxxxx"
  secret_key = "xxxxxxxxxxxxxxxxxxxxxxx"
}
variable "subnet_prefix" {
  description = "cidr block for the subnet"
  default = "10.0.66.0/24"
}
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id             = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}
resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = var.subnet_prefix[0].cidr_block
  availability_zone = "us-east-1a"

  tags = {
    Name = var.subnet_prefix[0].name
  }
}
resource "aws_subnet" "subnet-2" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = var.subnet_prefix[1]
  availability_zone = "us-east-1a"

  tags = {
    Name =  var.subnet_prefix[1].name
  }
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}
resource "aws_network_interface" "web-service-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

  
}
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-service-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]


}
output "server_public_ip" {
  value = aws_eip.one.public_ip
  
}
 
resource "aws_instance" "web_server_instance" {
  ami               = "ami-0ee23bfc74a881de5"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "Practice key pair"
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-service-nic.id
  }
  user_data = <<-EOF
  sudo apt update -y
  sudo apt install apache2 -y
  sudo systemctl start apache2
  sudo bash -c 'echo your very first web server > /var/www/html/index.html'
  EOF
  tags = {
    "name" = "web-server"
  }
}
output "server_private_ip" {
  value = aws_instance.web_server_instance.private_ip
}
output "server_id" {
  value = aws_instance.web_server_instance.id
}
