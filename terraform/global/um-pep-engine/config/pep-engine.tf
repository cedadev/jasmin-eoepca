resource "kubernetes_config_map" "pep_engine_cm" {
  metadata {
    name = "um-pep-engine-config"
  }

  data = {
    PEP_REALM                    = "eoepca"
    PEP_AUTH_SERVER_URL          = "${join("", ["http://", var.hostname])}"
    PEP_PROXY_ENDPOINT           = "/"
    PEP_SERVICE_HOST             = "0.0.0.0"
    PEP_SERVICE_PORT             = "5566"
    PEP_S_MARGIN_RPT_VALID       = "5"
    PEP_CHECK_SSL_CERTS          = "false"
    PEP_USE_THREADS              = "true"
    PEP_DEBUG_MODE               = "true"
    PEP_RESOURCE_SERVER_ENDPOINT = "http://ades/"
  }
}

resource "kubernetes_ingress" "gluu_ingress_pep_engine" {
  metadata {
    name = "gluu-ingress-pep-engine"

    annotations = {
      "kubernetes.io/ingress.class"              = "nginx"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "false"
    }
  }

  spec {
    rule {
      host = var.hostname

      http {
        path {
          path = "/pep"

          backend {
            service_name = "pep-engine"
            service_port = "5566"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "pep-engine" {
  metadata {
    name   = "pep-engine"
    labels = { app = "pep-engine" }
  }

  spec {
    type = "NodePort"

    port {
      name        = "http-pep"
      port        = 5566
      target_port = 5566
      node_port   = 31707
    }
    port {
      name        = "https-pep"
      port        = 1025
      target_port = 443
    }
    selector = { app = "pep-engine" }
  }
}


resource "kubernetes_deployment" "pep-engine" {
  metadata {
    name   = "pep-engine"
    labels = { app = "pep-engine" }
  }

  spec {
    replicas = 1
    selector {
      match_labels = { app = "pep-engine" }
    }
    template {
      metadata {
        labels = { app = "pep-engine" }
      }
      spec {

        automount_service_account_token = true
  
        volume {
          name = "vol-userman"
          persistent_volume_claim {
            claim_name = "eoepca-userman-pvc"
          }
        }
        volume {
          name = "resource-persistent-storage"
          persistent_volume_claim {
            claim_name = "resource-persistent-storage-volume-claim"
          }
        }
        container {
          name  = "pep-engine"
          image = "eoepca/um-pep-engine:latest"

          port {
            container_port = 5566
            name           = "http-pep"
          }
          port {
            container_port = 443
            name           = "https-pep"
          }
          env_from {
            config_map_ref {
              name = "um-pep-engine-config"
            }
          }
          volume_mount {
            name       = "resource-persistent-storage"
            mount_path = "/data/db/resource"
          }
          image_pull_policy = "Always"
        }
        container {
          name  = "mongo"
          image = "mongo"
          port {
            container_port = 27017
            name = "http-rp"
          }
        
          env_from {
            config_map_ref {
              name = "um-pep-engine-config"
            }
          }
          volume_mount {
            name       = "resource-persistent-storage"
            mount_path = "/data/db/resource"
          }
          image_pull_policy = "Always"
        }
        
        host_aliases {
          ip        = var.nginx_ip
          hostnames = [var.hostname]
        }
      }
    }
  }
}

