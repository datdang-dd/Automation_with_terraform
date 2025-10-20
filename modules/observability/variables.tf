variable "project_id"   { type = string }
variable "uptime_host"  { type = string }                      # có thể unknown ở plan

variable "region"{ 
  type = string
  default = "us-central1" 
}
variable "enable_uptime" { 
  type = bool  
  default = true 

}    # LB IP hoặc domain
variable "mig_name"     { type = string }        # ví dụ "web-mig"