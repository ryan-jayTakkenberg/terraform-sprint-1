terraform {
  required_providers {
    google = {
      source  = "hashicorp/google" # Geeft aan dat de Google Cloud provider wordt gebruikt.
      version = "4.51.0"           # Specificeert de versie van de Google provider.
    }
  }
}

# Resource: google_storage_bucket
# Maakt een nieuwe Google Cloud Storage bucket aan waarin de website-bestanden worden opgeslagen.
resource "google_storage_bucket" "website" {
  name          = "terraform-website-bucket-by-ryan" # De naam van de bucket.
  location      = "EU"                               # Locatie van de bucket.
  force_destroy = true                               # Forceert het verwijderen van de bucket inclusief inhoud.
}

# Resource: google_compute_network
# Creëert een VPC-netwerk (Virtual Private Cloud) waarin andere netwerkbronnen (zoals VM-instances) kunnen worden geplaatst.
resource "google_compute_network" "vpc_network" {
  name = "terraform-network" # Naam van het VPC-netwerk.
}

# Resource: google_storage_object_access_control
# Stelt de toegangsrechten in voor objecten binnen de Google Storage bucket, zodat ze publiek toegankelijk zijn.
resource "google_storage_object_access_control" "public_rule" {
  bucket = google_storage_bucket.website.name # Verwijst naar de naam van de aangemaakte bucket.
  object = google_storage_bucket_object.static_site_src.name # Verwijst naar het object (bestand) in de bucket.
  role   = "READER"                                        # Bepaalde rol, in dit geval 'READER' (leesrechten).
  entity = "allUsers"                                      # Geeft aan dat iedereen toegang heeft tot dit object.
}

# Resource: google_storage_bucket_object
# Uploadt het `index.html` bestand naar de bucket als een object, wat de startpagina van de website vormt.
resource "google_storage_bucket_object" "static_site_src" {
  name   = "index.html"                                  # Naam van het object (bestand) in de bucket.
  bucket = google_storage_bucket.website.name            # Verwijst naar de bucket waarin het object wordt geüpload.
  source = "../website/index.html"                       # Locatie van het bestand op de lokale machine dat moet worden geüpload.
}

# Resource: google_compute_global_address
# Reserveert een statisch IP-adres voor gebruik met de Load Balancer. Dit IP-adres wordt gebruikt als het frontend IP voor de website.
resource "google_compute_global_address" "website_ip" {
  name = "website-rt-ip" # Naam van het gereserveerde IP-adres.
}

# Data Source: google_dns_managed_zone
# Haalt de DNS managed zone op uit Google Cloud DNS. Deze zone bevat de DNS-records voor je domein.
data "google_dns_managed_zone" "dns_zone" {
  name = "terraform-gcp" # Naam van de DNS-zone (deze moet al bestaan in Google Cloud DNS).
}

# Resource: google_dns_record_set
# Creëert een DNS A-record in de opgehaalde DNS-zone. Dit record wijst het domein `website.sprint.review.cloud.` naar het gereserveerde IP-adres.
resource "google_dns_record_set" "website" {
  name         = "website.sprint.review.cloud."   # Corrigeer de FQDN naar 'website.sprint.review.cloud.'
  type         = "A"                              # Type DNS-record (A-record wijst naar een IP-adres).
  ttl          = 300                              # Time-to-Live (TTL) voor het DNS-record.
  managed_zone = data.google_dns_managed_zone.dns_zone.name   # Verwijst naar de DNS-zone.
  rrdatas      = [google_compute_global_address.website_ip.address] # Verwijst naar het gereserveerde IP-adres.
}

# Resource: google_compute_backend_bucket
# Creëert een backend-bucket die wordt gebruikt als een CDN (Content Delivery Network) voor de website. De bucket dient als backend voor de Load Balancer.
resource "google_compute_backend_bucket" "website-backend" {
  name        = "website-backend"                 # Naam van de backend-bucket.
  bucket_name = google_storage_bucket.website.name  # Verwijst naar de Google Storage bucket.
  description = "Contains files needed for the website" # Beschrijving van de bucket.
  enable_cdn  = true                                  # Schakelt Cloud CDN in om de bestanden wereldwijd te cachen.
}

# Resource: google_compute_url_map
# Creëert een URL-map die de inkomende URL-verzoeken naar het juiste backend (de backend-bucket) leidt.
resource "google_compute_url_map" "website-map" {
  name            = "website-map"                                        # Naam van de URL-map.
  default_service = google_compute_backend_bucket.website-backend.self_link # Standaard backend-service.
  
  host_rule {
    hosts        = ["*"]                  # Matcht alle hosts.
    path_matcher = "allpaths"             # Matcht alle paden.
  }

  path_matcher {
    name            = "allpaths"                                         # Naam van de path matcher.
    default_service = google_compute_backend_bucket.website-backend.self_link # Verwijst naar de backend-bucket.
  }
}

# Resource: google_compute_target_http_proxy
# Creëert een HTTP-proxy die de inkomende HTTP-verzoeken afhandelt en deze doorstuurt naar de URL-map.
resource "google_compute_target_http_proxy" "website" {
  name    = "website-target-proxy"               # Naam van de HTTP-proxy.
  url_map = google_compute_url_map.website-map.self_link # Verwijst naar de URL-map.
}

# Resource: google_compute_global_forwarding_rule
# Maakt een globale forwarding-regel die inkomende HTTP-verzoeken (poort 80) naar de HTTP-proxy leidt.
resource "google_compute_global_forwarding_rule" "default" {
  name                  = "website-forwarding-rule"         # Naam van de forwarding-regel.
  load_balancing_scheme = "EXTERNAL"                        # Geeft aan dat dit een externe forwarding-regel is.
  ip_address            = google_compute_global_address.website_ip.address # Verwijst naar het gereserveerde IP-adres.
  ip_protocol           = "TCP"                             # Gebruikt TCP voor communicatie.
  port_range            = "80"                              # Poortbereik, in dit geval poort 80 (HTTP).
  target                = google_compute_target_http_proxy.website.self_link # Verwijst naar de HTTP-proxy.
}



# Google Storage Bucket: Hierin worden de websitebestanden opgeslagen (index.html).
# VPC Netwerk: Een netwerk waarin andere bronnen kunnen worden geplaatst.
# Global IP Address: Reserveert een statisch IP-adres dat wordt gebruikt als het frontend IP voor de website.
# DNS Record Set: Verbindt het domein (website.sprint.review.cloud) met het gereserveerde IP-adres.
# Backend Bucket: Backend-bucket die fungeert als bron van de website en optioneel als CDN.
# HTTP Proxy en URL Map: Routeert inkomende verzoeken naar de juiste backend (de backend-bucket).
# Global Forwarding Rule: Verbindt het frontend IP en poort (80) met de HTTP-proxy.
