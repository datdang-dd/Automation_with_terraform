variable "project_id"        { type = string }
variable "region"            { type = string }
variable "bucket_name" {
  type = string
}
variable "downloader_emails" { 
    type = list(string)
    default = [] 
}
