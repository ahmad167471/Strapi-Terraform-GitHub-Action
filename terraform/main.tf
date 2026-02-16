variable "image_tag" {
  description = "Docker image tag to deploy (e.g. latest or 20260216-1356-01ffa8f)"
  type        = string
}

variable "ec2_ssh_private_key" {
  description = "Base64-encoded SSH private key for the EC2 instance"
  type        = string
  sensitive   = true
}

# ────────────────────────────────────────────────────────────────
#  Find your EXISTING EC2 instance
# ────────────────────────────────────────────────────────────────
data "aws_instance" "strapi_ec2" {
  # Option A: by tag (recommended once everything works)
  # filter {
  #   name   = "tag:Name"
  #   values = ["strapi-production"]
  # }

  # Option B: hardcode your instance ID (use this for now – fastest for debugging)
  instance_id = "i-07207b6a8e43ab850"  
}

output "ec2_public_ip" {
  description = "Public IP of the Strapi EC2 instance"
  value       = data.aws_instance.strapi_ec2.public_ip
}

resource "null_resource" "deploy_container" {
  triggers = {
    image_tag = var.image_tag
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"                     # Amazon Linux default user
    private_key = base64decode(var.ec2_ssh_private_key)
    host        = data.aws_instance.strapi_ec2.public_ip
    timeout     = "3m"                           # Fail faster if SSH doesn't connect
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [
      "echo '=== DEBUG: SSH connection successful ==='",
      "whoami",
      "pwd",
      "docker --version || echo 'Docker not found – please install it'",
      "echo '=== DEBUG END ==='",

      "echo 'Deploying Strapi ${var.image_tag}...'",
      "docker pull ahmad167471/strapi-app:${var.image_tag}",

      # Stop and remove old container (ignore errors if not found)
      "docker stop strapi || true",
      "docker rm strapi || true",

      # Run new container – REPLACE ALL PLACEHOLDERS BELOW
      <<EOC
      docker run -d \
        --name strapi \
        --restart unless-stopped \
        -p 1337:1337 \
        -e NODE_ENV=production \
        -e APP_KEYS=replace-with-real-random-keys,comma,separated,at-least-3 \
        -e API_TOKEN_SALT=replace-with-very-long-random-salt-64-chars \
        -e ADMIN_JWT_SECRET=replace-with-very-long-random-secret-64-chars \
        -e JWT_SECRET=replace-with-another-very-long-random-secret-64-chars \
        -e DATABASE_CLIENT=postgres \
        -e DATABASE_HOST=your-rds-endpoint.ap-south-1.rds.amazonaws.com \
        -e DATABASE_PORT=5432 \
        -e DATABASE_NAME=your_database_name \
        -e DATABASE_USERNAME=your_rds_username \
        -e DATABASE_PASSWORD=your_real_database_password \
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
