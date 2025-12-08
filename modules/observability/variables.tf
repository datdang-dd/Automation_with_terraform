variable "project_id"   { type = string }
variable "uptime_host"  { type = string }                      # có thể unknown ở plan

variable "region"{ 
  type = string
}
variable "enable_uptime" { 
  type = bool  
  default = true 

}    # LB IP hoặc domain
variable "mig_name"     { type = string }        # ví dụ "web-mig"

# Optional: enable disk usage alert (requires Ops Agent metrics present)
variable "enable_disk_alert" {
  type    = bool
  default = false
}