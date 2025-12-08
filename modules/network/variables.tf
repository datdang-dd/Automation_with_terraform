variable "project_id"  { type = string }
variable "region"      { type = string }
variable "vpc_name"    { type = string }
variable "subnet_name" { type = string }
variable "subnet_cidr" { type = string }
variable "ssh_cidr"    { type = list(string) }
variable "grafana_allowed_cidr" {
  type = string
}