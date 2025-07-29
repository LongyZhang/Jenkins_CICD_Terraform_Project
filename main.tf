provider "aws" {
  region = "us-east-1"  # Change if you're in a different region
}

data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

# Amazon linux 2 from AWS Marketplace (for us-east-1)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
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

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "main-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"  # Adjust as needed
  tags = { Name = "public-subnet" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  map_public_ip_on_launch = false
  availability_zone = "us-east-1a"  # Adjust as needed
  tags = { Name = "private-subnet" }
  
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "public_nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.igw]
  tags =  {Name = "public-nat-gateway"}  
}


resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
}


resource "aws_route" "private_rt_nat" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_nat_gateway.public_nat.id
}


resource "aws_route_table_association" "assoc_private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private_rt.id
  
}




resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "ssh_sg" {
  name   = "allow_ssh"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.body)}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rdp" {
  name= "allow_rdp"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.body)}/32"]
  }
}


resource "aws_security_group" "vpc_sg" {
  name   = "allow access from subnet"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.public.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_key_pair" "my_key" {
  key_name   = "my-key"
  public_key = file("~/.ssh/id_rsa.pub")  # adjust path as needed
} 

# List of node names
locals {
  instance_names = [
    "GITLAB-node",
    "JENKINS-node",
    "DOCKER-node"
    
  ]
}

locals {
  public_instance_names = [
    "VPN-node"
  ]
}


resource "aws_instance" "nodes" {
  count         = length(local.instance_names)
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "m4.large"
  subnet_id     = aws_subnet.private.id
  key_name      = aws_key_pair.my_key.key_name
  vpc_security_group_ids = [aws_security_group.ssh_sg.id,aws_security_group.vpc_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name


  user_data = file("user_data/user_data.sh")

  tags = {
    Name = local.instance_names[count.index]
  }
}



data "aws_ami" "windows" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter { 
    name   = "platform"
    values = ["windows"]
  }

  owners = ["801119661308"] # Amazon's official Windows AMIs
}


resource "aws_instance" "public_nodes" {
  count         = length(local.public_instance_names)
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "m4.large"
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.my_key.key_name
  vpc_security_group_ids = [aws_security_group.ssh_sg.id,aws_security_group.vpc_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  # get_password_data = true
  user_data = file("user_data/user_data.sh")

  tags = {
    Name = local.public_instance_names[count.index]
  }
}



resource "aws_iam_role" "ssm_role" {
  name = "ssm-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ssm-profile"
  role = aws_iam_role.ssm_role.name
}
