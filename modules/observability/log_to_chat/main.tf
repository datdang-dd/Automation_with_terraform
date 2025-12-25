resource "google_monitoring_notification_channel" "chat" {
  project      = var.project_id
  display_name = "Google Chat – Audit Alerts"
  type         = "google_chat"

  labels = {
    # Thay đổi mã Space bên dưới nếu bạn muốn gửi vào phòng chat khác
    space = "spaces/AAQAGKxqmro"
  }
}
# ------ ALert for create new -------
resource "google_monitoring_alert_policy" "master_audit_alert" {
  project      = var.project_id
  display_name = "🚨 Security Alert: Critical Resources Created"
  
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Match Critical Audit Logs"
    condition_matched_log {
      filter = <<EOT
        (logName="projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity" OR logName="projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Fsystem_event")
        AND (
          (
            (operation.last=true OR NOT operation.id:*)
            AND (
              (resource.type="gce_instance" AND (protoPayload.methodName:"v1.compute.instances.insert" OR protoPayload.methodName:"beta.compute.instances.insert"))
              
              OR
              (resource.type="gce_firewall_rule" AND (protoPayload.methodName:"beta.compute.firewalls.insert" OR protoPayload.methodName:"v1.compute.firewalls.insert"))
              
              OR
              (resource.type="gce_disk" AND protoPayload.methodName:"compute.disks.insert")
              
              OR
              (resource.type="gce_snapshot" AND protoPayload.methodName:"compute.snapshots.insert")
              
              OR
              (resource.type="gce_disk" AND protoPayload.methodName:"ScheduledSnapshots" AND protoPayload.response.operationType:"createSnapshot")
              
              OR
              (resource.type="gce_network" AND (protoPayload.methodName:"v1.compute.networks.insert" OR protoPayload.methodName:"beta.compute.networks.insert"))
              
              OR
              (resource.type="gke_cluster" AND protoPayload.methodName:"google.container.v1.ClusterManager.CreateCluster")
              
              OR
              (resource.type="cloudsql_database" AND (protoPayload.methodName:"cloudsql.instances.create" OR protoPayload.methodName:"cloud.sql.v1beta4.SqlInstancesService.Insert"))
              
              OR
              (resource.type="gcs_bucket" AND protoPayload.methodName:"storage.buckets.create")
              
              OR
              (resource.type="audited_resource" AND (
                protoPayload.methodName:"google.api.serviceusage.v1.ServiceUsage.EnableService" OR
                protoPayload.methodName:"google.cloud.run.v2.Services.CreateService"
              ))
            )
          )

          OR
          (
            (resource.type="bigquery_dataset" AND (
               protoPayload.methodName:"google.cloud.bigquery.v2.DatasetService.InsertDataset" OR
               protoPayload.methodName:"google.cloud.bigquery.v2.TableService.InsertTable"
            ))
            
            OR
            (resource.type="audited_resource" AND (
               protoPayload.methodName:"google.cloud.aiplatform.v1.EndpointService.CreateEndpoint" OR
               protoPayload.methodName:"google.cloud.aiplatform.v1.JobService.CreateCustomJob"
            ))

            OR
            (resource.type="cloud_dataproc_cluster" AND jsonPayload.class:"org.apache.hadoop.mapreduce" )
            
            OR
            ((resource.type="cloud_run_job" OR resource.type="cloud_run_revision" OR resource.type="audited_resource") AND 
            (protoPayload.methodName:"google.cloud.run.v2.Services.CreateService" OR protoPayload.methodName:"google.cloud.run.v2.Services.UpdateService"))
            
            OR
            (resource.type="service_account" AND protoPayload.methodName:"google.iam.admin.v1.CreateServiceAccount")
            
            OR
            (resource.type="service_account" AND protoPayload.methodName:"google.iam.admin.v1.CreateServiceAccountKey")
          )
        )
      EOT
    }
  }

  # Cấu hình auto_close để dọn dẹp dashboard sau 30p
  alert_strategy {
    notification_rate_limit {
      period = "300s" # Tối thiểu 5 phút
    }
    auto_close = "1800s"
  }

  notification_channels = [google_monitoring_notification_channel.chat.id]
}


# ==============================================================================
# 1. TẠO METRIC (Cập nhật label để khớp với JSON của bạn)
# ==============================================================================
resource "google_logging_metric" "resource_creation_metric" {
  project = var.project_id
  # Tên metric này sẽ khớp với phần "logging.googleapis.com/user/..." trong JSON
  name    = "report-for-new-resources_test" 
  
  # Lấy filter từ Alert Policy để đảm bảo đồng bộ
  filter  = google_monitoring_alert_policy.master_audit_alert.conditions[0].condition_matched_log[0].filter

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    
    # Label 1: resource_type (như gce_instance)
    labels {
      key         = "resource_type"
      value_type  = "STRING"
      description = "Resource Type"
    }

    # Label 2: Đặt tên là "service" để khớp với JSON UI của bạn
    # Nhưng giá trị thực tế sẽ là methodName (chi tiết hành động)
    labels {
      key         = "service"
      value_type  = "STRING"
      description = "Method Name / API Action"
    }
  }

  label_extractors = {
    "resource_type" = "EXTRACT(resource.type)"
    
    # Lấy nguyên gốc methodName, KHÔNG dùng Regex (đúng yêu cầu của bạn)
    "service"       = "EXTRACT(protoPayload.methodName)"
  }
}

# ==============================================================================
# 2. TẠO DASHBOARD (Sử dụng chính xác JSON bạn cung cấp)
# ==============================================================================
resource "google_monitoring_dashboard" "resource_report_dashboard" {
  project        = var.project_id
  # Sử dụng heredoc syntax (<<EOF) để paste JSON vào dễ dàng
  dashboard_json = <<EOF
{
  "displayName": "Weekly Resource Creation Report (Terraform)",
  "gridLayout": {
    "columns": "2",
    "widgets": [
      {
        "title": "Daily Created Resources by Method",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"logging.googleapis.com/user/${google_logging_metric.resource_creation_metric.name}\"",
                  "aggregation": {
                    "perSeriesAligner": "ALIGN_SUM",
                    "crossSeriesReducer": "REDUCE_SUM",
                    "groupByFields": [
                      "metric.label.\"service\"",
                      "metric.label.\"resource_type\""
                    ],
                    "alignmentPeriod": "86400s"
                  }
                }
              },
              "plotType": "STACKED_BAR",
              "targetAxis": "Y1",
              "minAlignmentPeriod": "86400s"
            }
          ],
          "chartOptions": {
            "mode": "COLOR",
            "displayHorizontal": false
          },
          "thresholds": [],
          "yAxis": {
            "scale": "LINEAR",
            "label": "Total Count"
          }
        }
      }
    ]
  }
}
EOF
}



# --------Alert for delete --------

resource "google_monitoring_alert_policy" "master_audit_alert_delete" {
  project      = var.project_id
  display_name = "🚨 Security Alert: Critical Resources Deleted"
  
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Match Critical Audit Logs"
    condition_matched_log {
      filter = <<EOT
        (logName="projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Factivity" OR logName="projects/${var.project_id}/logs/cloudaudit.googleapis.com%2Fsystem_event")
        AND
          (
            (operation.last=true OR NOT operation.id:*)
            AND (
              (protoPayload.methodName:"google.api.serviceusage.v1.ServiceUsage.DisableService")

              OR
              (resource.type="gcs_bucket" AND protoPayload.methodName:"storage.buckets.delete")

              OR
              (resource.type="gce_firewall_rule" AND protoPayload.methodName:"firewalls.delete")

              OR
              (resource.type="gce_instance" AND protoPayload.methodName:"compute.instances.delete")

              OR 
              (resource.type="gce_disk" AND protoPayload.methodName:"v1.compute.disks.delete")

              OR 
              (resource.type="project" AND protoPayload.serviceName:"cloudresourcemanager.googleapis.com" AND protoPayload.methodName:"SetIamPolicy" AND protoPayload.serviceData.policyDelta.bindingDeltas.action:"Remove")

              OR
              (resource.type ="gce_snapshot" AND protoPayload.methodName:"v1.compute.snapshots.delete")

              OR 
              (resource.type="gce_network" AND protoPayload.methodName:"v1.compute.networks.delete")

              OR
              (resource.type="cloudsql_database" AND protoPayload.methodName:"cloudsql.instances.delete")

              OR 
              ((resource.type="bigquery_dataset" AND protoPayload.methodName:"google.cloud.bigquery.v2.TableService.DeleteTable") OR
              (resource.type="bigquery_dataset" AND protoPayload.methodName:"google.cloud.bigquery.v2.DatasetService.DeleteDataset"))

              OR
              ((resource.type="cloud_run_service" OR resource.type="cloud_run_revision" OR resource.type="audited_resource") 
              AND protoPayload.methodName:"google.cloud.run.v1.Services.DeleteService")

              OR 
              (resource.type="service_account" AND protoPayload.methodName:"google.iam.admin.v1.DeleteServiceAccount")
              
              OR 
              (resource.type="service_account" AND protoPayload.methodName:"google.iam.admin.v1.DeleteServiceAccountKey")
            )
          )
      EOT
    }
  }
  # Cấu hình auto_close để dọn dẹp dashboard sau 30p
  alert_strategy {
    notification_rate_limit {
      period = "300s" # Tối thiểu 5 phút
    }
    auto_close = "1800s"
  }

  notification_channels = [google_monitoring_notification_channel.chat.id]
}


# ==============================================================================
# 3. TẠO METRIC (Cập nhật label để khớp với JSON của bạn)
# ==============================================================================
resource "google_logging_metric" "resource_deteted_metric" {
  project = var.project_id
  # Tên metric này sẽ khớp với phần "logging.googleapis.com/user/..." trong JSON
  name    = "report-for-delete-resources" 
  
  # Lấy filter từ Alert Policy để đảm bảo đồng bộ
  filter  = google_monitoring_alert_policy.master_audit_alert_delete.conditions[0].condition_matched_log[0].filter

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    
    # Label 1: resource_type (như gce_instance)
    labels {
      key         = "resource_type"
      value_type  = "STRING"
      description = "Resource Type"
    }

    # Label 2: Đặt tên là "service" để khớp với JSON UI của bạn
    # Nhưng giá trị thực tế sẽ là methodName (chi tiết hành động)
    labels {
      key         = "service"
      value_type  = "STRING"
      description = "Method Name / API Action"
    }
  }

  label_extractors = {
    "resource_type" = "EXTRACT(resource.type)"
    
    # Lấy nguyên gốc methodName, KHÔNG dùng Regex (đúng yêu cầu của bạn)
    "service"       = "EXTRACT(protoPayload.methodName)"
  }
}

# ==============================================================================
# 4. TẠO DASHBOARD (Sử dụng chính xác JSON bạn cung cấp)
# ==============================================================================
resource "google_monitoring_dashboard" "resource_report_dashboard_for_delete" {
  project        = var.project_id
  # Sử dụng heredoc syntax (<<EOF) để paste JSON vào dễ dàng
  dashboard_json = <<EOF
{
  "displayName": "Weekly Resource Deleted Report (Terraform)",
  "gridLayout": {
    "columns": "2",
    "widgets": [
      {
        "title": "Daily Deleted Resources by Method",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"logging.googleapis.com/user/${google_logging_metric.resource_creation_metric.name}\"",
                  "aggregation": {
                    "perSeriesAligner": "ALIGN_SUM",
                    "crossSeriesReducer": "REDUCE_SUM",
                    "groupByFields": [
                      "metric.label.\"service\"",
                      "metric.label.\"resource_type\""
                    ],
                    "alignmentPeriod": "86400s"
                  }
                }
              },
              "plotType": "STACKED_BAR",
              "targetAxis": "Y1",
              "minAlignmentPeriod": "86400s"
            }
          ],
          "chartOptions": {
            "mode": "COLOR",
            "displayHorizontal": false
          },
          "thresholds": [],
          "yAxis": {
            "scale": "LINEAR",
            "label": "Total Count"
          }
        }
      }
    ]
  }
}
EOF
}