variable "region"               { type = string }

variable "zone" {
  type = string
}
variable "machine_type"         { type = string }
variable "ssh_public_key"       { type = string }
variable "subnetwork_self_link" { type = string }
variable "target_tags"          { type = list(string) }
variable "service_account"      { type = string }
variable "size_min" { 
    type = number
    default = 2 
    }
variable "size_max"  { 
    type = number
    default = 4 
}
