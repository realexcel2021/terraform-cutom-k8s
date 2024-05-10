variable "access_key" { #Todo: uncomment the default value and add your access key.
        description = "Access key to AWS console"
        default = "" 
}

variable "secret_key" {  #Todo: uncomment the default value and add your secert key.
        description = "Secret key to AWS console"
        default = "" 
}

variable "session_token" {
  type = string
  description = "sesion token for temporary access"
}

variable "private_ip_ha_proxy" {
  type = string
  description = "private ip address for ha proxy"
}

variable "number_of_worker" {
        description = "number of worker instances to be join on cluster."
}

variable "region" {
        description = "The region zone on AWS"
        default = "us-east-1" #The zone I selected is us-east-1, if you change it make sure to check if ami_id below is correct.
}

variable "ami_id" {
        description = "The AMI to use"
        default = "ami-0a6b2839d44d781b2" #Ubuntu 20.04
}

variable "instance_type" {
        default = "t2.medium" #the best type to start k8s with it,
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}