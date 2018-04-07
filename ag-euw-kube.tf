resource "azurerm_resource_group" "kube" {
  name     = "ag-euw-kube-rg"
  location = "West Europe"
}

resource "azurerm_network_security_group" "kube" {
  name                = "ag-euw-kube-nsg"
  location            = "${azurerm_resource_group.kube.location}"
  resource_group_name = "${azurerm_resource_group.kube.name}"

  security_rule {
    name                       = "kube-allow-ssh"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "kube-allow-api-server"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "kube" {
  name                = "ag-euw-kube-vnet"
  resource_group_name = "${azurerm_resource_group.kube.name}"
  address_space       = ["10.172.0.0/16"]
  location            = "${azurerm_resource_group.kube.location}"

  subnet {
    name           = "kube-subnet"
    address_prefix = "10.172.1.0/24"
    security_group = "${azurerm_network_security_group.kube.id}"
  }
}

resource "azurerm_public_ip" "kubeapi" {
  name                         = "ag-euw-kube-api-pip"
  location                     = "${azurerm_resource_group.kube.location}"
  resource_group_name          = "${azurerm_resource_group.kube.name}"
  public_ip_address_allocation = "static"
}

resource "azurerm_lb" "kubeapi" {
  name                = "ag-euw-kube-api-lb"
  location            = "${azurerm_resource_group.kube.location}"
  resource_group_name = "${azurerm_resource_group.kube.name}"

  frontend_ip_configuration {
    name                 = "kubeapi-lb-pip"
    public_ip_address_id = "${azurerm_public_ip.kubeapi.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "kubeapi" {
  resource_group_name = "${azurerm_resource_group.kube.name}"
  loadbalancer_id     = "${azurerm_lb.kubeapi.id}"
  name                = "kubeapi-lb-pool"
}
