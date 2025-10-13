variable "project_id"        { type = string }
variable "region"            { type = string }
variable "bucket_name_opt"   { 
    type = string 
    default = null 
}
variable "downloader_emails" { 
    type = list(string)
    default = [] 
}
