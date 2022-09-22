#
# Define tags as a local and push down to all the modules via the provider default_tags.
# See below default_tags below
#
locals {
    common_tags = {
    Environment = var.env
  }
}

locals {
    id_tag = var.vpc_tag_key != "" ? tomap({(var.vpc_tag_key) = (var.vpc_tag_value)}) : {}
}

#
# Provider default_tags
# ref: https://www.hashicorp.com/blog/default-tags-in-the-terraform-aws-provider
#
provider "aws" {
  region     = var.aws_region
  default_tags {
    tags = merge(local.common_tags, local.id_tag)
  }
}

#
# Local variables for splitting up the subnets and assigning host IP's from within the cidr block
#
locals {
  availability_zone = "${var.aws_region}${var.availability_zone}"
}

locals {
  public_subnet_cidr = cidrsubnet(var.vpc_cidr_security, var.subnet_bits, var.public_subnet_index)
}
locals {
  private_subnet_cidr = cidrsubnet(var.vpc_cidr_security, var.subnet_bits, var.private_subnet_index)
}
locals {
  fortigate_public_ip = cidrhost(local.public_subnet_cidr, var.fgt_host_ip)
}
locals {
  fortigate_private_ip = cidrhost(local.private_subnet_cidr, var.fgt_host_ip)
}
locals {
  linux_private_ip = cidrhost(local.private_subnet_cidr, var.linux_host_ip)
}

locals {
  linux_private2_ip = cidrhost(local.public_subnet_cidr, var.linux_host_ip)
}

#
# Some resources need unique names (e.g. security groups).
# Generate a random string and append to any resources that need unique names
#
resource "random_string" "random" {
  length           = 5
  special          = false
}

#
# AMI to be used by the PAYGO instance of Fortigate
# Change the foritos_version and the use_fortigate_byol variables in terraform.tfvars to change it
#
data "aws_ami" "fortigate_paygo" {
  most_recent = true

  filter {
    name                         = "name"
    values                       = ["FortiGate-VM64-AWSONDEMAND * (${var.fortios_version}) GA*"]
  }

  filter {
    name                         = "virtualization-type"
    values                       = ["hvm"]
  }

  owners                         = ["679593333241"] # Canonical
}

data "template_file" "fgt_userdata_paygo" {
  template = file("./config_templates/fgt-userdata-paygo.tpl")

  vars = {
    fgt_id                = var.fortigate_instance_name
    Port1IP               = local.fortigate_public_ip
    Port2IP               = local.fortigate_private_ip
    PrivateSubnet         = local.private_subnet_cidr
    security_cidr         = var.vpc_cidr_security
    PublicSubnetRouterIP  = cidrhost(local.public_subnet_cidr, 1)
    public_subnet_mask    = cidrnetmask(local.public_subnet_cidr)
    private_subnet_mask   = cidrnetmask(local.private_subnet_cidr)
    PrivateSubnetRouterIP = cidrhost(local.private_subnet_cidr, 1)
    fgt_admin_password    = var.fgt_admin_password
    ServiceDNSName        = lookup(aws_vpc_endpoint.endpoint_az1.dns_entry[0], "dns_name")
  }
}


#
# Fortigate HA Pair and IAM Profiles
#
module "iam_profile" {
  source = "git::https://github.com/40netse/terraform-modules.git//aws_ec2_instance_iam_role"
  iam_role_name = "${var.cp}-${var.env}-${random_string.random.result}-fortigate-instance_role"
}

#
# This is an "allow all" security group, but a place holder for a more strict SG
#
module "allow_private_subnets" {
  source = "git::https://github.com/40netse/terraform-modules.git//aws_security_group"
  sg_name= "${var.cp}-${var.env}-${random_string.random.result}-${var.fgt_sg_name} Allow Private Subnets"

  vpc_id                  = module.base-vpc.vpc_id
  ingress_to_port         = 0
  ingress_from_port       = 0
  ingress_protocol        = "-1"
  ingress_cidr_for_access = "0.0.0.0/0"
  egress_to_port          = 0
  egress_from_port        = 0
  egress_protocol         = "-1"
  egress_cidr_for_access  = "0.0.0.0/0"
}

#
# This is an "allow all" security group, but a place holder for a more strict SG
#
module "allow_public_subnets" {

  source = "git::https://github.com/40netse/terraform-modules.git//aws_security_group"
  sg_name= "${var.cp}-${var.env}-${random_string.random.result}-${var.fgt_sg_name} Allow Public Subnets"

  vpc_id                  = module.base-vpc.vpc_id
  ingress_to_port         = 0
  ingress_from_port       = 0
  ingress_protocol        = "-1"
  ingress_cidr_for_access = var.cidr_for_access
  egress_to_port          = 0
  egress_from_port        = 0
  egress_protocol         = "-1"
  egress_cidr_for_access  = "0.0.0.0/0"
}

#
# Security VPC, IGW, Subnets, Route Tables, Route Table Associations
#
module "base-vpc" {
  source = "git::https://github.com/40netse/base_vpc_single_az.git"

  aws_region                 = var.aws_region
  environment                = var.env
  customer_prefix            = var.cp
  availability_zone          = var.availability_zone
  vpc_name_security          = var.vpc_name_security
  vpc_cidr_security          = var.vpc_cidr_security
  subnet_bits                = var.subnet_bits
  public_subnet_index        = var.public_subnet_index
  private_subnet_index       = var.private_subnet_index
  public_description         = var.public_description
  private_description        = var.private_description
  vpc_tag_key                = var.vpc_tag_key
  vpc_tag_value              = var.vpc_tag_value

}

#
# VPC that runs the exposed services, IGW, Subnets, Route Tables, Route Table Associations
#
module "base-vpc2" {
  source = "git::https://github.com/40netse/base_vpc_single_az.git"

  aws_region                 = var.aws_region
  environment                = var.env2
  customer_prefix            = var.cp
  availability_zone          = var.availability_zone
  vpc_name_security          = var.vpc_name_security
  vpc_cidr_security          = var.vpc_cidr_security
  subnet_bits                = var.subnet_bits
  public_subnet_index        = var.public_subnet_index
  private_subnet_index       = var.private_subnet_index
  public_description         = var.public_description
  private_description        = var.private_description
  vpc_tag_key                = var.vpc_tag_key
  vpc_tag_value              = var.vpc_tag_value
}

resource "aws_default_route_table" "default_route" {
  default_route_table_id = module.base-vpc.vpc_main_route_table_id
  tags = {
    Name = "default table for base vpc (unused)"
  }
}

#
# Single Fortigate in AZ1. Using a generic ec2_instance module. Only AP pairs use the sync and mgmt interfaces,
# so disabled for a single instance.
#
# use create_public_elastic_ip bool if you want EIPs on the public interface
#
module "fortigate" {
  depends_on                  = [ aws_vpc_endpoint.endpoint_az1 ]
  source                      = "git::https://github.com/40netse/terraform-modules.git//aws_ec2_instance"

  aws_ec2_instance_name       = "${var.cp}-${var.env}-${var.vpc_name_security}-${var.fortigate_instance_name}"
  availability_zone           = local.availability_zone
  enable_private_interface    = true
  enable_sync_interface       = false
  enable_hamgmt_interface     = false
  enable_public_ips           = true
  enable_mgmt_public_ips      = false
  public_subnet_id            = module.base-vpc.public_subnet_id
  public_ip_address           = local.fortigate_public_ip
  private_subnet_id           = module.base-vpc.private_subnet_id
  private_ip_address          = local.fortigate_private_ip
  aws_ami                     = data.aws_ami.fortigate_paygo.id
  keypair                     = var.keypair
  instance_type               = var.fortigate_instance_type
  security_group_private_id   = module.allow_private_subnets.id
  security_group_public_id    = module.allow_public_subnets.id
  acl                         = var.acl
  iam_instance_profile_id     = module.iam_profile.id
  userdata_rendered           = data.template_file.fgt_userdata_paygo.rendered
}

#
# Point the private route table default route to the Fortigate Private ENI
#
resource "aws_route" "private" {
  route_table_id         = module.base-vpc.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.fortigate.network_private_interface_id[0]
}


module "private_route_table_association" {
  source                     = "git::https://github.com/40netse/terraform-modules.git//aws_route_table_association"

  subnet_ids                 = module.base-vpc.private_subnet_id
  route_table_id             = module.base-vpc.private_route_table_id
}

#
# Linux Instances from here down. This instance runs the exposed service. In this example case, SSH, HTTP is all.
#

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20220609"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

module "ec2-sg" {
  source                  = "git::https://github.com/40netse/terraform-modules.git//aws_security_group"
  sg_name                 = "${var.cp}-${var.env}-${random_string.random.result}-${var.ec2_sg_name} Allow East Subnets"
  vpc_id                  = module.base-vpc.vpc_id

  ingress_to_port         = 0
  ingress_from_port       = 0
  ingress_protocol        = "-1"
  ingress_cidr_for_access = "0.0.0.0/0"
  egress_to_port          = 0
  egress_from_port        = 0
  egress_protocol         = "-1"
  egress_cidr_for_access  = "0.0.0.0/0"
}

module "ec2-sg-vpc2" {
  source                  = "git::https://github.com/40netse/terraform-modules.git//aws_security_group"
  sg_name                 = "${var.cp}-${var.env2}-${random_string.random.result}-${var.ec2_sg_name} Allow East Subnets"
  vpc_id                  = module.base-vpc2.vpc_id

  ingress_to_port         = 0
  ingress_from_port       = 0
  ingress_protocol        = "-1"
  ingress_cidr_for_access = "0.0.0.0/0"
  egress_to_port          = 0
  egress_from_port        = 0
  egress_protocol         = "-1"
  egress_cidr_for_access  = "0.0.0.0/0"
}


#
# IAM Profile for linux instance
#
module "linux_iam_profile" {
  source = "git::https://github.com/40netse/terraform-modules.git//aws_ec2_instance_iam_role"
  iam_role_name = "${var.cp}-${var.env}-${random_string.random.result}-linux-instance_role"
}

#
# Linux Instances config template
#

data "template_file" "web_userdata" {
  template = file("./config_templates/web-userdata.tpl")
}

#
# East Linux Instance for Generating East->West Traffic
#
module "aws_linux_instance" {
  source                      = "git::https://github.com/40netse/terraform-modules.git//aws_ec2_instance"
  aws_ec2_instance_name       = "${var.cp}-${var.env}-${var.linux_instance_name}"
  enable_public_ips           = false
  availability_zone           = local.availability_zone
  public_subnet_id            = module.base-vpc.private_subnet_id
  public_ip_address           = local.linux_private_ip
  aws_ami                     = data.aws_ami.ubuntu.id
  keypair                     = var.keypair
  instance_type               = var.linux_instance_type
  security_group_public_id    = module.ec2-sg.id
  acl                         = var.acl
  iam_instance_profile_id     = module.linux_iam_profile.id
  userdata_rendered           = data.template_file.web_userdata.rendered
}

module "aws_linux_instance2" {
  source                      = "git::https://github.com/40netse/terraform-modules.git//aws_ec2_instance"
  aws_ec2_instance_name       = "${var.cp}-${var.env2}-${var.linux_instance_name}"
  enable_public_ips           = true
  availability_zone           = local.availability_zone
  public_subnet_id            = module.base-vpc2.public_subnet_id
  public_ip_address           = local.linux_private2_ip
  aws_ami                     = data.aws_ami.ubuntu.id
  keypair                     = var.keypair
  instance_type               = var.linux_instance_type
  security_group_public_id    = module.ec2-sg-vpc2.id
  acl                         = var.acl
  iam_instance_profile_id     = module.linux_iam_profile.id
  userdata_rendered           = data.template_file.web_userdata.rendered
}

data "aws_caller_identity" "current" {}

#
# NLB used for termination of Private Link from Endpoint. Listeners and port 22 and 80
# Target group is the Linux instances above.
#
resource "aws_lb" "private_nlb" {
  name = "internal"
  internal = true
  load_balancer_type = "network"
  enable_cross_zone_load_balancing = false
  subnets = [ module.base-vpc2.public_subnet_id ]
}

resource "aws_lb_listener" "nlb_listener_http" {
  load_balancer_arn = aws_lb.private_nlb.arn
  port = "80"
  protocol = "TCP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.private_nlb_target_group_http.arn
  }
}

resource "aws_lb_listener" "nlb_listener_ssh" {
  load_balancer_arn = aws_lb.private_nlb.arn
  port = "22"
  protocol = "TCP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.private_nlb_target_group_ssh.arn
  }
}

resource "aws_vpc_endpoint_service" "endpoint_service" {
  acceptance_required        = false
  allowed_principals         = []
  network_load_balancer_arns = [aws_lb.private_nlb.arn]
  tags = {
    Name        = "${var.cp}-${var.env}-endpoint-service"
  }
}

resource "aws_vpc_endpoint" "endpoint_az1" {
  depends_on        = [ aws_vpc_endpoint_service.endpoint_service ]
  service_name      = aws_vpc_endpoint_service.endpoint_service.service_name
  subnet_ids        = [module.base-vpc.private_subnet_id]
  vpc_endpoint_type = aws_vpc_endpoint_service.endpoint_service.service_type
  vpc_id            = module.base-vpc.vpc_id
  security_group_ids = [ module.ec2-sg.id ]
  tags = {
    Name        = "${var.cp}-${var.env}-endpoint"
  }
}

resource "aws_lb_target_group" "private_nlb_target_group_http" {
  name      = "internal-http"
  port      = 80
  protocol  = "TCP"
  vpc_id    = module.base-vpc2.vpc_id
}

resource "aws_lb_target_group" "private_nlb_target_group_ssh" {
  name      = "internal-ssh"
  port      = 22
  protocol  = "TCP"
  vpc_id    = module.base-vpc2.vpc_id
}

resource "aws_lb_target_group_attachment" "nlb_target_group_att_ssh" {
  target_group_arn = aws_lb_target_group.private_nlb_target_group_ssh.arn
  target_id = module.aws_linux_instance2.instance_id
}

resource "aws_lb_target_group_attachment" "nlb_target_group_att_http" {
  target_group_arn = aws_lb_target_group.private_nlb_target_group_http.arn
  target_id = module.aws_linux_instance2.instance_id
}