resource "aws_vpc" "hdvpc" {
  cidr_block = var.vpcip
}

resource "aws_subnet" "hdsub1" {
  vpc_id     = aws_vpc.hdvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  
}

resource "aws_subnet" "hdsub2" {
  vpc_id     = aws_vpc.hdvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.hdvpc.id

}

#route table distination block

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.hdvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

#route table target block for subnet1 
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.hdsub1.id
  route_table_id = aws_route_table.rt.id
}

#route table target block for subnet2 

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.hdsub2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "hdSg" {
  name        = "web"
  vpc_id      = aws_vpc.hdvpc.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_s3_bucket" "example" {
  bucket = "hdesais3bucket"
}

resource "aws_instance" "webserver1" {
  ami                    = "ami-04b4f1a9cf54c11d0"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.hdSg.id]
  subnet_id              = aws_subnet.hdsub1.id
  user_data              = base64encode(file("userdata.sh"))
}

resource "aws_instance" "webserver2" {
  ami                    = "ami-04b4f1a9cf54c11d0"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.hdSg.id]
  subnet_id              = aws_subnet.hdsub2.id
  user_data              = base64encode(file("userdata1.sh"))
}

resource "aws_lb" "hdalb" {
  name               = "hdalb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.hdSg.id]
  subnets         = [aws_subnet.hdsub1.id, aws_subnet.hdsub2.id]

  tags = {
    Name = "web"
  }
}

resource "aws_lb_target_group" "hdtg" {
  name     = "myTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.hdvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.hdtg.arn
  target_id        = aws_instance.webserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.hdtg.arn
  target_id        = aws_instance.webserver2.id
  port             = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.hdalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.hdtg.arn
    type             = "forward"
  }
}

output "loadbalancerdns" {
  value = aws_lb.hdalb.dns_name
} 
