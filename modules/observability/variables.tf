variable "project_id"   { type = string }
variable "enable_uptime" { 
    type = bool
    default = false 
    }   # <— thêm
variable "uptime_host"  { type = string }                      # có thể unknown ở plan
