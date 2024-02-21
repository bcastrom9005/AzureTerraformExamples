/*

The following links provide the documentation for the new blocks used
in this terraform configuration file

1.azurerm_windows_virtual_machine - https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/windows_virtual_machine

*/

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.10.0"
    }
  }
}

provider "azurerm" {
  subscription_id = "your subscripionId"
  tenant_id = "your tenantId"
  client_id = "your clientId / applicationId"
  client_secret = "your clientSecret"
  features {}  
}

//Create variables 

locals {
    resource_group_name="rg_automation_terraform"
    location="North Europe"
    virtual_network={
        name="automation_network"
        address_space="10.0.0.0/16"
    }

    subnets=[
        {
            name="subnetA"
            address_prefix="10.0.0.0/24"
        },
        {
           name="subnetB"
            address_prefix="10.0.1.0/24" 
        }
    ]

}


resource "azurerm_resource_group" "rg_1" {
  name     = local.resource_group_name
  location = local.location
}

resource "azurerm_virtual_network" "network_1" {
  name                = local.virtual_network.name
  address_space       = [local.virtual_network.address_space]
  location            = local.location
  resource_group_name = local.resource_group_name
  depends_on = [ azurerm_resource_group.rg_1 ]
}

resource "azurerm_subnet" "Subnet_1" {
  name                 = local.subnets[0].name
  resource_group_name  = local.resource_group_name
  virtual_network_name = local.virtual_network.name
  address_prefixes     =  [local.subnets[0].address_prefix]
  depends_on = [ azurerm_virtual_network.network_1 ]
}

resource "azurerm_subnet" "Subnet_2" {
  name                 = local.subnets[1].name
  resource_group_name  = local.resource_group_name
  virtual_network_name = local.virtual_network.name
  address_prefixes     =  [local.subnets[1].address_prefix]
  depends_on = [ azurerm_virtual_network.network_1 ]
}



resource "azurerm_network_interface" "network_interface" {
  name                = "automation_nic"
  location            = local.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.Subnet_1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.appip.id
  }
  depends_on = [ azurerm_subnet.Subnet_1 ]
}

resource "azurerm_public_ip" "appip" {
  name                = "app-ip"
  resource_group_name = local.resource_group_name
  location            = local.location
  allocation_method   = "Static"
 depends_on = [
   azurerm_resource_group.rg_1
 ]
}

resource "azurerm_network_security_group" "automation_nsg" {
  name                = "app-nsg"
  location            = local.location
  resource_group_name = local.resource_group_name

  security_rule {
    name                       = "AllowRDP"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  depends_on = [
    azurerm_resource_group.rg_1
  ]
}

resource "azurerm_subnet_network_security_group_association" "automation_nsglink" {
  subnet_id                 = azurerm_subnet.Subnet_1.id
  network_security_group_id = azurerm_network_security_group.automation_nsg.id
}


resource "azurerm_windows_virtual_machine" "autovm" {
  name                = "autovmmachine"
  resource_group_name = local.resource_group_name
  location            = local.location
  size                = "Standard_B1ms"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.network_interface.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
  depends_on = [ azurerm_network_interface.network_interface, azurerm_resource_group.rg_1 ]
}