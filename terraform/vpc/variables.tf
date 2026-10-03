variable "aws_region"    { default = "ap-south-1" }
variable "project_name"  { default = "three-tier" }
variable "cluster_name"  { default = "three-tier-cluster" }
variable "my_ip"         { description = "Your IP for Jenkins access e.g. 1.2.3.4/32" }
variable "key_pair_name" { description = "EC2 Key Pair name" }
variable "jenkins_ami"   { default = "ami-0f5ee92e2d63afc18" } # Amazon Linux 2 ap-south-1
