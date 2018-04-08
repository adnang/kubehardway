resource "azurerm_resource_group" "kube" {
  name     = "ag-euw-kube-rg"
  location = "West Europe"
}

resource "azurerm_virtual_network" "kube" {
  name                = "ag-euw-kube-vnet"
  resource_group_name = "${azurerm_resource_group.kube.name}"
  address_space       = ["10.172.0.0/16"]
  location            = "${azurerm_resource_group.kube.location}"
}
