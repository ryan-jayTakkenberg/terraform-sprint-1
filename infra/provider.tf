provider "google" {
  credentials = file("${path.module}/ryanproject12-f2c0a48df702.json")
  project     = var.gcp_project
  region      = var.gcp_region
}