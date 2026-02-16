provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "strapi" {
  ami           = "ami-0c1fe732b5494dc14"
  instance_type = "t2.micro"
  key_name      = "Pearl-Thoughts"
  vpc_security_group_ids = [aws_security_group.allow_http.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install docker -y
              systemctl start docker
              usermod -aG docker ec2-user

              docker pull ahmad167471/strapi:${var.image_tag}
              docker run -d -p 80:1337 ahmad167471/strapi:${var.image_tag}
              EOF

  tags = {
    Name = "Strapi-App"
  }
}

output "public_ip" {
  value = aws_instance.strapi.public_ip
}
