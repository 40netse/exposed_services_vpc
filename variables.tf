variable "aws_region" {
  description = "The AWS region to use"
}
variable "availability_zone" {
  description = "Availability Zone for VPC"
}
variable subnet_bits {
  description = "Number of bits in the network portion of the subnet CIDR"
}
variable "public_subnet_index" {
  description = "Index of the public subnet"
}
variable "private_subnet_index" {
  description = "Index of the private subnet"
}
variable "keypair" {
  description = "Keypair for instances that support keypairs"
}
variable "cp" {
  description = "Customer Prefix to apply to all resources"
}
variable "env" {
  description = "The Tag Environment to differentiate prod/test/dev"
}
variable "env2" {
  description = "The Tag Environment2 to differentiate prod/test/dev"
}
variable "vpc_name_security" {
    description = "Name of Security VPC"
}
variable "vpc_cidr_security" {
    description = "CIDR for the whole security VPC"
}
variable "fgt_admin_password" {
  description = "Fortigate Admin Password"
}
variable "fortios_version" {
  description = "FortiOS Version for the AMI Search String"
}
variable "fgt_host_ip" {
  description = "Fortigate Host IP for all subnets"
}
variable "public_description" {
    description = "Description Public Subnet TAG"
}
variable "private_description" {
    description = "Description Private Subnet TAG"
}
variable "vpc_tag_key" {
    description = "Random Tag Key to place on VPC for data ID"
    default     = ""
}
variable "vpc_tag_value" {
    description = "Random Tag Value to place on VPC for data ID"
    default     = ""
}
variable "cidr_for_access" {
  description = "CIDR to use for security group access"
}
variable "fortigate_instance_type" {
  description = "Instance type for fortigates"
}
variable "fortigate_instance_name" {
  description = "Instance Name for fortigate"
}
variable "acl" {
  description = "The S3 acl"
}
variable "fgt_sg_name" {
  description = "Fortigate Security Group Name"
}
variable "ec2_sg_name" {
  description = "Linux Endpoint Security Group Name"
}
variable "linux_instance_name" {
  description = "Linux Endpoint Instance Name"
}
variable "linux_instance_type" {
  description = "Linux Endpoint Instance Type"
}
variable "linux_host_ip" {
  description = "Fortigate Host IP for all subnets"
}
