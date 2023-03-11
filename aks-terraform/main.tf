terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.45.0"
    }
  }
  backend "azurerm" {
    resource_group_name = "XXX"
    storage_account_name = "XXX"
    container_name = "terraform-backend"
    key = "terraform.tfstate"
    use_msi              = true
    subscription_id ="XXX"  ## your subscription id
    tenant_id = "XXX"  ## your tenant_id
  }
}

provider "azurerm" {
  features {
  }
  use_msi              = true
  subscription_id ="XXX"  ## your subscription id
  tenant_id = "XXX"  ## your tenant_id
}



resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.prefix}-aks"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  dns_prefix          = "${var.prefix}"

  default_node_pool {
    name       = var.prefix
    node_count = 1
    vm_size    = "Standard_D2as_v4"
  }

  identity {
     type = "SystemAssigned"
  }
}

#  This resource requires a wait time that doesnt really fit with using pipeline

data "azurerm_resources" "example" {
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group

  type = "Microsoft.Network/networkSecurityGroups"
  }

resource "azurerm_network_security_rule" "example" {
  name                        = "example"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "30000-32767"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_kubernetes_cluster.aks.node_resource_group
  network_security_group_name = data.azurerm_resources.example.resources.0.name

}

data "azurerm_lb" "lb" {
  name                = "Kubernetes"
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group
}

resource "azurerm_lb_probe" "probe_30001" {
  loadbalancer_id = data.azurerm_lb.lb.id
  name            = "probe-30001"
  port            = 30001
}

resource "azurerm_lb_probe" "probe_30002" {
  loadbalancer_id = data.azurerm_lb.lb.id
  name            = "probe-30002"
  port            = 30002
}

data "azurerm_lb_backend_address_pool" "backend_pool" {
  name            = "kubernetes"
  loadbalancer_id = data.azurerm_lb.lb.id
}

resource "azurerm_lb_rule" "rule30001" {
  loadbalancer_id                = data.azurerm_lb.lb.id
  name                           = "rule30001"
  protocol                       = "Tcp"
  frontend_port                  = 30001
  backend_port                   = 30001
  frontend_ip_configuration_name = "${data.azurerm_lb.lb.frontend_ip_configuration.0.name}"
  backend_address_pool_ids = [data.azurerm_lb_backend_address_pool.backend_pool.id]
  disable_outbound_snat = true
}

resource "azurerm_lb_rule" "rule30002" {
  loadbalancer_id                = data.azurerm_lb.lb.id
  name                           = "rule30002"
  protocol                       = "Tcp"
  frontend_port                  = 30002
  backend_port                   = 30002
  frontend_ip_configuration_name = "${data.azurerm_lb.lb.frontend_ip_configuration.0.name}"
  backend_address_pool_ids = [data.azurerm_lb_backend_address_pool.backend_pool.id]
  disable_outbound_snat = true
}

data "azurerm_public_ips" "example" {
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group
  attachment_status   = "Attached"
}
output "public_ip" {
  value = data.azurerm_public_ips.example.public_ips[0]
}