variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
}

variable "ec2_ssh_private_key" {
  description = "Base64-encoded SSH private key for the EC2 instance"
  type        = string
  sensitive   = true
}

data "aws_instance" "strapi_ec2" {
  # Option A: by tag (recommended) — make sure your EC2 has this exact tag
  filter {
    name   = "tag:Name"
    values = ["strapi-production"]   # ← CHANGE THIS if your instance has a different Name tag
  }

  # Option B: use this instead if you prefer (uncomment and comment out the filter block)
  # instance_id = "i-0123456789abcdef0"   # ← your real instance ID
}

output "ec2_public_ip" {
  value = data.aws_instance.strapi_ec2.public_ip
}

resource "null_resource" "deploy_container" {
  triggers = {
    image_tag = var.image_tag
  }

  connection {
  type        = "ssh"
  user        = "ec2-user"               # ← change from "ubuntu" to "ec2-user"
  private_key = base64decode(var.ec2_ssh_private_key)
  host        = data.aws_instance.strapi_ec2.public_ip
  timeout     = "5m"
}
  provisioner "remote-exec" {
    inline = [
      "echo 'Deploying Strapi ${var.image_tag}...'",
      "docker pull ahmad167471/strapi-app:${var.image_tag}",

      # Stop and remove old container (if exists) — ignore errors if not found
      "docker stop strapi || true",
      "docker rm strapi || true",

      # Run new container
      <<EOC
      docker run -d \
        --name strapi \
        --restart unless-stopped \
        -p 1337:1337 \
        -e NODE_ENV=production \
        -e APP_KEYS=change-this-to-random-32-chars,comma,separated \
        -e API_TOKEN_SALT=change-this-to-another-random-32-chars \
        -e ADMIN_JWT_SECRET=change-this-to-very-secure-random-64-chars \
        -e JWT_SECRET=change-this-to-very-secure-random-64-chars \
        -e DATABASE_CLIENT=postgres \
        -e DATABASE_HOST=your-real-rds-endpoint.rds.amazonaws.com \
        -e DATABASE_PORT=5432 \
        -e DATABASE_NAME=strapi_prod \
        -e DATABASE_USERNAME=your_real_db_username \
        -e DATABASE_PASSWORD=your_strong_db_password_here \
        -v strapi-data:/app/public/uploads \
        ahmad167471/strapi-app:${var.image_tag}
      EOC
      ,

      "docker ps | grep strapi || echo 'Container not visible yet – wait 10-30 seconds'",
      "echo 'Deployment finished. Check:'",
      "echo 'http://${data.aws_instance.strapi_ec2.public_ip}:1337/admin'"
    ]
  }
}
