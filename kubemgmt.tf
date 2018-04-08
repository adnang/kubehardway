variable "mgmtvmpwd" {}

## Network resources

resource "azurerm_network_security_group" "kubemgmt" {
  name                = "ag-euw-kube-mgmt-nsg"
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
}

resource "azurerm_subnet" "kubemgmt" {
  name                      = "kubemgmt-subnet"
  address_prefix            = "10.172.2.0/24"
  network_security_group_id = "${azurerm_network_security_group.kubemgmt.id}"
  virtual_network_name      = "${azurerm_virtual_network.kube.name}"
  resource_group_name       = "${azurerm_resource_group.kube.name}"
}

resource "azurerm_public_ip" "kubemgmt" {
  name                         = "ag-euw-kube-mgmt-pip"
  location                     = "${azurerm_resource_group.kube.location}"
  resource_group_name          = "${azurerm_resource_group.kube.name}"
  public_ip_address_allocation = "static"
}

## Compute resources

resource "azurerm_network_interface" "kubemgmt" {
  name                    = "ag-euw-kube-mgmt-nic"
  location                = "${azurerm_resource_group.kube.location}"
  resource_group_name     = "${azurerm_resource_group.kube.name}"
  enable_ip_forwarding    = true
  internal_dns_name_label = "kubectl-mgmt-node"

  ip_configuration {
    name                          = "kubemgmt-nic-cfg"
    subnet_id                     = "${azurerm_subnet.kubemgmt.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.kubemgmt.id}"
  }
}

resource "azurerm_virtual_machine" "kubemgmt" {
  name                  = "ag-euw-kube-mgmt1"
  location              = "${azurerm_resource_group.kube.location}"
  resource_group_name   = "${azurerm_resource_group.kube.name}"
  network_interface_ids = ["${azurerm_network_interface.kubemgmt.id}"]
  vm_size               = "Standard_A1_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "kubemgmt-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "ag-euw-kube-mgmt1"
    admin_username = "myadmin"
    admin_password = "${var.mgmtvmpwd}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}
