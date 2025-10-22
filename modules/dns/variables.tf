variable "project_id" {
  type = string
}

variable "zone_name" {
  description = "(Optional) Use an existing Cloud DNS managed zone name. If empty, module will create a new managed zone using `managed_zone_name` and `dns_name`."
  type        = string
  default     = ""
}

variable "managed_zone_name" {
  description = "Name to create when creating a new managed zone"
  type        = string
  default     = "demo-managed-zone"
}

variable "dns_name" {
  description = "DNS name for the managed zone when creating one (must end with a dot): e.g. example.com." 
  type        = string
  default     = ""
}

variable "domain" {
  description = "The domain (hostname) you want to point to the load balancer (e.g., example.com or www.example.com)"
  type        = string
}

variable "lb_ip" {
  description = "IP address of the load balancer to create an A record for"
  type        = string
}

variable "ttl" {
  description = "TTL for the A record"
  type        = number
  default     = 300
}
