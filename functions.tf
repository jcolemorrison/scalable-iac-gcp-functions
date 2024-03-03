# Create a storage bucket for the function source code
resource "google_storage_bucket" "bucket" {
  name                        = "${var.project_name}-gcf-source"
  location                    = "US"
  uniform_bucket_level_access = true
}

# TBD - add source code to bucket from external repo
# resource "google_storage_bucket_object" "object" {
#   name   = "function-source.zip"
#   bucket = google_storage_bucket.bucket.name
#   source = "function-source.zip"  # Add path to the zipped function source code
# }

# Create a Cloud Function for each region
resource "google_cloudfunctions2_function" "function" {
  count = length(var.deployment_regions)

  name     = format("fn-%s-%d", var.deployment_regions[count.index], count.index + 1)
  location = var.deployment_regions[count.index]

  build_config {
    runtime = "nodejs20"

    # entry_point = "main"  # TBD - get name from external function source

    source {
      storage_source {
        bucket = google_storage_bucket.bucket.name

        # TBD - add source code to bucket from external repo
        # object = google_storage_bucket_object.object.name
      }
    }
  }

  service_config {
    vpc_connector                 = google_vpc_access_connector.vpc_connector[count.index].id
    vpc_connector_egress_settings = "ALL_TRAFFIC"
    ingress_settings              = "ALLOW_ALL"
  }
}

# Create a Network Endpoint Group for each Cloud Function
resource "google_compute_region_network_endpoint_group" "serverless_endpoints" {
  count  = length(var.deployment_regions)
  name   = format("send-%s-%d", var.deployment_regions[count.index], count.index + 1)
  region = var.deployment_regions[count.index]

  # TBD - may need to change back to run since v2 functions are deployed as Cloud Run
  # If this is the case, the backend will need to be updated to use the cloud_run block with the function name
  cloud_function {
    function = google_cloudfunctions2_function.function[count.index].name
  }
}

# Create a backend service
resource "google_compute_backend_service" "serverless_service" {
  name                  = "serverless-service"
  protocol              = "HTTP"
  port_name             = "http"
  enable_cdn            = false
  load_balancing_scheme = "EXTERNAL_MANAGED"

  dynamic "backend" {
    for_each = google_compute_region_network_endpoint_group.serverless_endpoints
    content {
      group = backend.value.id
    }
  }
}

# Create a URL map
resource "google_compute_url_map" "url_map" {
  name            = "url-map"
  default_service = google_compute_backend_service.serverless_service.self_link
}

# Create an HTTP proxy
resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "http-proxy"
  url_map = google_compute_url_map.url_map.self_link
}

# Create a global forwarding rule
resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name                  = "forwarding-rule"
  target                = google_compute_target_http_proxy.http_proxy.self_link
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# Create a custom role for public access
resource "google_project_iam_custom_role" "public_access_role" {
  role_id     = "publicAccessRole"
  title       = "Public Access Role"
  description = "A role that allows invoking permissions for Cloud Functions"
  project     = var.gcp_project_id
  permissions = [
    "cloudfunctions.functions.invoke",
  ]
}

# Grant public access role to each Cloud Function
resource "google_cloudfunctions2_function_iam_binding" "public_access" {
  count          = length(var.deployment_regions)
  project        = var.gcp_project_id
  location       = var.deployment_regions[count.index]
  cloud_function = google_cloudfunctions2_function.function[count.index].name
  role           = google_project_iam_custom_role.public_access_role.id
  members = [
    "allUsers",
  ]
}

output "forwarding_rule_ip" {
  description = "The IP address of the global forwarding rule"
  value       = google_compute_global_forwarding_rule.forwarding_rule.ip_address
}