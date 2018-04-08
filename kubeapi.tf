variable "apivmpwd" {}

## Network Resources

resource "azurerm_network_security_group" "kubeapi" {
  name                = "ag-euw-kube-api-nsg"
  location            = "${azurerm_resource_group.kube.location}"
  resource_group_name = "${azurerm_resource_group.kube.name}"

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

resource "azurerm_subnet" "kubeapi" {
  name                      = "kubeapi-subnet"
  address_prefix            = "10.172.1.0/24"
  network_security_group_id = "${azurerm_network_security_group.kubeapi.id}"
  virtual_network_name      = "${azurerm_virtual_network.kube.name}"
  resource_group_name       = "${azurerm_resource_group.kube.name}"
}

## Load Balancer Resources

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

## Compute Resources

resource "azurerm_availability_set" "kubeapi" {
  name                = "ag-euw-kube-api-as"
  location            = "${azurerm_resource_group.kube.location}"
  resource_group_name = "${azurerm_resource_group.kube.name}"
  managed             = true
}

resource "azurerm_network_interface" "kubeapi" {
  count                   = 3
  name                    = "ag-euw-kube-api-nic${count.index}"
  location                = "${azurerm_resource_group.kube.location}"
  resource_group_name     = "${azurerm_resource_group.kube.name}"
  enable_ip_forwarding    = true
  internal_dns_name_label = "kubectl-pool-node${count.index}"

  ip_configuration {
    name                                    = "kubeapi-nic-cfg"
    subnet_id                               = "${azurerm_subnet.kubeapi.id}"
    private_ip_address_allocation           = "dynamic"
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.kubeapi.id}"]
  }
}

resource "azurerm_managed_disk" "kubeapi" {
  count                = 3
  name                 = "ag-euw-kube-api-disk${count.index}"
  location             = "${azurerm_resource_group.kube.location}"
  resource_group_name  = "${azurerm_resource_group.kube.name}"
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1"
}

resource "azurerm_virtual_machine" "kubeapi" {
  count                 = 3
  name                  = "ag-euw-kube-api-node${count.index}"
  location              = "${azurerm_resource_group.kube.location}"
  resource_group_name   = "${azurerm_resource_group.kube.name}"
  network_interface_ids = ["${element(azurerm_network_interface.kubeapi.*.id,count.index)}"]
  vm_size               = "Standard_A1_v2"
  availability_set_id   = "${azurerm_availability_set.kubeapi.id}"

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
    name              = "kubeapi-node${count.index}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "ag-euw-kube-api-node${count.index}"
    admin_username = "myadmin"
    admin_password = "${var.apivmpwd}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  storage_data_disk {
    name            = "${element(azurerm_managed_disk.kubeapi.*.name, count.index)}"
    managed_disk_id = "${element(azurerm_managed_disk.kubeapi.*.id, count.index)}"
    create_option   = "Attach"
    lun             = 1
    disk_size_gb    = "${element(azurerm_managed_disk.kubeapi.*.disk_size_gb, count.index)}"
  }
}
