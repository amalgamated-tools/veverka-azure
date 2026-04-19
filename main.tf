terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "azurerm" {
  features {}
}

# Resource group
resource "azurerm_resource_group" "veverka" {
  name     = "veverka-rg"
  location = var.location
}

# Virtual network
resource "azurerm_virtual_network" "veverka" {
  name                = "veverka-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.veverka.location
  resource_group_name = azurerm_resource_group.veverka.name
}

# Subnet
resource "azurerm_subnet" "veverka" {
  name                 = "veverka-subnet"
  resource_group_name  = azurerm_resource_group.veverka.name
  virtual_network_name = azurerm_virtual_network.veverka.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group (firewall)
resource "azurerm_network_security_group" "veverka" {
  name                = "veverka-nsg"
  location            = azurerm_resource_group.veverka.location
  resource_group_name = azurerm_resource_group.veverka.name

  # Allow SSH inbound
  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTP inbound
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTPS inbound
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow outbound all (default)
  security_rule {
    name                       = "AllowOutbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Public IP addresses (one per VM for SSH access)
resource "azurerm_public_ip" "veverka" {
  for_each            = toset(var.vm_names)
  name                = "${lower(each.value)}-pip"
  location            = azurerm_resource_group.veverka.location
  resource_group_name = azurerm_resource_group.veverka.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network interfaces
resource "azurerm_network_interface" "veverka" {
  for_each            = toset(var.vm_names)
  name                = "${lower(each.value)}-nic"
  location            = azurerm_resource_group.veverka.location
  resource_group_name = azurerm_resource_group.veverka.name

  ip_configuration {
    name                          = "${lower(each.value)}-ipconfig"
    subnet_id                     = azurerm_subnet.veverka.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.veverka[each.value].id
  }
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "veverka" {
  subnet_id                 = azurerm_subnet.veverka.id
  network_security_group_id = azurerm_network_security_group.veverka.id
}

# Managed disks (OS disks)
resource "azurerm_managed_disk" "veverka" {
  for_each            = toset(var.vm_names)
  name                = "${lower(each.value)}-osdisk"
  location            = azurerm_resource_group.veverka.location
  resource_group_name = azurerm_resource_group.veverka.name
  storage_account_type = "Premium_LRS"
  create_option       = "Empty"
  disk_size_gb        = 30
}

# Virtual machines
resource "azurerm_linux_virtual_machine" "veverka" {
  for_each            = toset(var.vm_names)
  name                = each.value
  location            = azurerm_resource_group.veverka.location
  resource_group_name = azurerm_resource_group.veverka.name
  size                = var.vm_size

  admin_username = "azureuser"

  # SSH key authentication
  admin_ssh_key {
    username   = "azureuser"
    public_key = var.ssh_public_key
  }

  # OS disk
  os_disk {
    caching           = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  # Source image (Ubuntu 22.04 LTS)
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Network interface
  network_interface_ids = [
    azurerm_network_interface.veverka[each.value].id,
  ]

  # Tags for organization
  tags = {
    Name        = each.value
    Environment = "production"
    Project     = "veverka"
  }
}

# Output public IPs for SSH access
output "vm_public_ips" {
  description = "Public IP addresses for SSH access"
  value = {
    for name in var.vm_names : name => azurerm_public_ip.veverka[name].ip_address
  }
}

# Output private IPs for internal networking
output "vm_private_ips" {
  description = "Private IP addresses for internal networking"
  value = {
    for name in var.vm_names : name => azurerm_network_interface.veverka[name].private_ip_address
  }
}

# Output resource group info
output "resource_group" {
  description = "Resource group details"
  value = {
    name     = azurerm_resource_group.veverka.name
    location = azurerm_resource_group.veverka.location
  }
}
