# Create a VPC network
resource "google_compute_network" "vpc_network" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false
}

# Create subnets
resource "google_compute_subnetwork" "subnet" {
  count                    = length(var.deployment_regions)
  name                     = format("subnet-%s-%d", var.deployment_regions[count.index], count.index + 1)
  ip_cidr_range            = cidrsubnet(var.vpc_cidr_block, 12, count.index)
  network                  = google_compute_network.vpc_network.self_link
  region                   = var.deployment_regions[count.index]
  private_ip_google_access = true
}

# Create VPC connectors
resource "google_vpc_access_connector" "vpc_connector" {
  count  = length(var.deployment_regions)
  name   = format("vpc-con-%s-%d", var.deployment_regions[count.index], count.index + 1)
  region = var.deployment_regions[count.index]
  subnet {
    name = google_compute_subnetwork.subnet[count.index].name
  }
}