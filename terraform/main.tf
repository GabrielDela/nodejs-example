terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.48.0"
    }
  }

  backend "azurerm" {

  }
}

provider "azurerm" {
  features {

  }
}

####################
# RESOURCE GROUP   #
####################

# resource "azurerm_resource_group" "rg" {
#   name     = "rg-${var.project_name}${var.environment_suffix}"
#   location = "West Europe"
# }

####################
# DATABASE SECTION #
####################

resource "azurerm_postgresql_server" "postgres-server" {
  name                = "postgres-server-${var.project_name}${var.environment_suffix}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  sku_name = "B_Gen5_2"

  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true

  administrator_login          = data.azurerm_key_vault_secret.database-login.value
  administrator_login_password = data.azurerm_key_vault_secret.database-password.value
  version                      = "9.5"
  ssl_enforcement_enabled      = false
  ssl_minimal_tls_version_enforced = "TLSEnforcementDisabled"

}

resource "azurerm_postgresql_firewall_rule" "firewall" {
  name                = "firewall-${var.project_name}${var.environment_suffix}"
  resource_group_name = data.azurerm_resource_group.rg.name
  server_name         = azurerm_postgresql_server.postgres-server.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

# resource "azurerm_postgresql_database" "postgres-db" {
#   name                = "postgres-db-${var.project_name}${var.environment_suffix}"
#   resource_group_name = data.azurerm_resource_group.rg.name
#   server_name         = azurerm_postgresql_server.postgres-server.name
#   charset             = "UTF8"
#   collation           = "English_United States.1252"
# }

####################
# WEB APP SECTION  #
####################

resource "azurerm_service_plan" "app_plan" {
  name                = "app-plan-${var.project_name}${var.environment_suffix}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "S1"
}

resource "azurerm_linux_web_app" "web_app" {
  name                = "web-app-${var.project_name}${var.environment_suffix}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.app_plan.id

  site_config {
    
  }
}

####################
# API SECTION      #
####################
resource "azurerm_container_group" "api" {
  name                = "aci-api-${var.project_name}${var.environment_suffix}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  ip_address_type     = "Public"
  dns_name_label      = "aci-api-${var.project_name}${var.environment_suffix}"
  os_type             = "Linux"

  container {
    name   = "api"
    image  = "gabrieldela/nodejs-example:1.0"
    cpu    = "0.5"
    memory = "1.5"

    ports {
      port     = 3000
      protocol = "TCP"
    }

    environment_variables = {
      "PORT"        = var.api_port
      "DB_HOST"     = azurerm_postgresql_server.postgres-server.fqdn
      "DB_USERNAME" = "${data.azurerm_key_vault_secret.database-login.value}@${azurerm_postgresql_server.postgres-server.name}"
      "DB_PASSWORD" = data.azurerm_key_vault_secret.database-password.value
      "DB_DATABASE" = var.database_name
      "DB_DAILECT"  = var.database_dialect
      "DB_PORT"     = var.database_port

      "ACCESS_TOKEN_SECRET"       = data.azurerm_key_vault_secret.access-token.value
      "REFRESH_TOKEN_SECRET"      = data.azurerm_key_vault_secret.refresh-token.value
      "ACCESS_TOKEN_EXPIRY"       = var.access_token_expiry
      "REFRESH_TOKEN_EXPIRY"      = var.refresh_token_expiry
      "REFRESH_TOKEN_COOKIE_NAME" = var.refresh_token_cookie_name
    }
  }
}

####################
# PGADMIN SECTION  #
####################

resource "azurerm_container_group" "pgadmin" {
  name                = "aci-pgadmin-${var.project_name}${var.environment_suffix}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  ip_address_type     = "Public"
  dns_name_label      = "aci-pgadmin-${var.project_name}${var.environment_suffix}"
  os_type             = "Linux"

  container {
    name   = "pgadmin"
    image  = "dpage/pgadmin4:latest"
    cpu    = "1"
    memory = "4"

    ports {
      port     = 80
      protocol = "TCP"
    }

    environment_variables = {
      "PGADMIN_DEFAULT_EMAIL"    = data.azurerm_key_vault_secret.pgadmin-login.value
      "PGADMIN_DEFAULT_PASSWORD" = data.azurerm_key_vault_secret.pgadmin-password.value
    }
  }
}