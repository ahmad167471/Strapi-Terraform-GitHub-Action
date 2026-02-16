# ─────────────────────────────────────────────
# AWS Provider (REQUIRED)
# ─────────────────────────────────────────────
provider "aws" {
  region = "us-east-1"
}

# ─────────────────────────────────────────────
# Variables
# ─────────────────────────────────────────────
variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
}

variable "ec2_ssh_private_key" {
  description = "Base64-encoded SSH private key"
  type        = string
  sensitive   = true
}

# ─────────────────────────────────────────────
# Find Existing EC2
# ─────────────────────────────────────────────
data "aws_instance" "strapi_ec2" {
  instance_id = "i-07207b6a8e43ab850"
}

output "ec2_public_ip" {
  value = data.aws_instance.strapi_ec2.public_ip
}

# ─────────────────────────────────────────────
# Deploy Container via SSH
# ─────────────────────────────────────────────
resource "null_resource" "deploy_container" {

  triggers = {
    image_tag = var.image_tag
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = base64decode(var.ec2_ssh_private_key)
    host        = data.aws_instance.strapi_ec2.public_ip
    timeout     = "3m"
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'SSH connected'",
      "docker pull ahmad167471/strapi-app:${var.image_tag}",
      "docker stop strapi || true",
      "docker rm strapi || true",
      "docker run -d --name strapi -p 1337:1337 ahmad167471/strapi-app:${var.image_tag}"
    ]
  }
}
