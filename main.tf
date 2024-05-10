provider "aws" {
  region     = var.region
}

resource "random_string" "s3name" {
  length = 9
  special = false
  upper = false
  lower = true
}

resource "aws_s3_bucket_acl" "s3_bucket_acl" {
  bucket = aws_s3_bucket.s3buckit.id
  acl    = "private"
  depends_on = [aws_s3_bucket_ownership_controls.s3_bucket_acl_ownership]
}

resource "aws_s3_bucket_ownership_controls" "s3_bucket_acl_ownership" {
  bucket = aws_s3_bucket.s3buckit.id
  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket" "s3buckit" {
  bucket = "k8s-${random_string.s3name.result}"
  force_destroy = true
 depends_on = [
    random_string.s3name
  ]
}

resource "aws_key_pair" "kube_cp_key" {
  key_name   = "etkube-cp-instance-key"
  public_key = data.tls_public_key.private_key_pem.public_key_openssh
}

resource "tls_private_key" "ed25519" {
  algorithm = "RSA"
}

# Public key loaded from a terraform-generated private key, using the PEM (RFC 1421) format
data "tls_public_key" "private_key_pem" {
  private_key_pem = tls_private_key.ed25519.private_key_pem
}

resource "local_file" "ssh_key" {
  filename = "${aws_key_pair.kube_cp_key.key_name}.pem"
  content  = tls_private_key.ed25519.private_key_pem
}

resource "aws_instance" "ec2_instance_msr" {
    ami = var.ami_id
    subnet_id = var.subnet_ids[0]
    instance_type = var.instance_type
    key_name = aws_key_pair.kube_cp_key.key_name
    associate_public_ip_address = true
    security_groups = [ aws_security_group.k8s_sg.id ]
    root_block_device {
    volume_type = "gp2"
    volume_size = "16"
    delete_on_termination = true
    }
    tags = {
        Name = "k8s_msr_1"
    }
    user_data_base64 = base64encode("${templatefile("${path.module}/scripts/install_k8s_msr.sh", {

    access_key = var.access_key
    private_key = var.secret_key
    region = var.region
    s3buckit_name = "k8s-${random_string.s3name.result}"
    loadbalancer_endpoint = "${var.private_ip_ha_proxy}"
    session_token = "${var.session_token}"
    })}")

    depends_on = [
    aws_s3_bucket.s3buckit,
    random_string.s3name
  ]
    
} 



resource "aws_instance" "ec2_instance_msr_2" {
    ami = var.ami_id
    subnet_id = var.subnet_ids[1]
    instance_type = var.instance_type
    key_name = aws_key_pair.kube_cp_key.key_name
    associate_public_ip_address = true
    security_groups = [ aws_security_group.k8s_sg.id ]
    root_block_device {
    volume_type = "gp2"
    volume_size = "16"
    delete_on_termination = true
    }
    tags = {
        Name = "k8s_msr_2"
    }
    user_data_base64 = base64encode("${templatefile("/scripts/install_k8s_msr2.sh", {
    access_key = var.access_key
    private_key = var.secret_key
    region = var.region
    s3buckit_name = "k8s-${random_string.s3name.result}"
    session_token = "${var.session_token}"
    })}")

    depends_on = [
    aws_s3_bucket.s3buckit,
    random_string.s3name,
    aws_instance.ec2_instance_msr
  ]
    
} 


resource "aws_instance" "ha_proxy" {
    ami = var.ami_id
    subnet_id = var.subnet_ids[1]
    private_ip = var.private_ip_ha_proxy
    instance_type = var.instance_type
    key_name = aws_key_pair.kube_cp_key.key_name
    associate_public_ip_address = true
    security_groups = [ aws_security_group.k8s_sg.id ]
    root_block_device {
    volume_type = "gp2"
    volume_size = "16"
    delete_on_termination = true
    }
    tags = {
        Name = "k8s_ha_proxy"
    }
    user_data_base64 = base64encode("${templatefile("scripts/loadbalancer.sh", {

      master_1 = "${aws_instance.ec2_instance_msr.private_ip}"
      master_2 = "${aws_instance.ec2_instance_msr_2.private_ip}"
    })}")
    
    
} 

resource "aws_instance" "ec2_instance_wrk" {
    ami = var.ami_id
    count = var.number_of_worker
    subnet_id = var.subnet_ids[1]
    instance_type = var.instance_type
    key_name = aws_key_pair.kube_cp_key.key_name
    associate_public_ip_address = true
    security_groups = [ aws_security_group.k8s_sg.id ]
    root_block_device {
    volume_type = "gp2"
    volume_size = "16"
    delete_on_termination = true
    }
    tags = {
        Name = "k8s_wrk_${count.index + 1}"
    }
    user_data_base64 = base64encode("${templatefile("scripts/install_k8s_wrk.sh", {

    access_key = var.access_key
    private_key = var.secret_key
    region = var.region
    s3buckit_name = "k8s-${random_string.s3name.result}"
    worker_number = "${count.index + 1}"
    session_token = "${var.session_token}"
    })}")
  
    depends_on = [
      aws_s3_bucket.s3buckit,
      random_string.s3name,
      aws_instance.ec2_instance_msr
  ]
} 