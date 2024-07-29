resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = var.resource_group_name
}

# Cria rede virtual
resource "azurerm_virtual_network" "vnet" {
  name                = "student-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Cria subnets
resource "azurerm_subnet" "subnet" {
  name                 = "student-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Cria IPs públicos
resource "azurerm_public_ip" "public_ip" {
  name                = "student-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Cria SG para HTTP
resource "azurerm_network_security_group" "sec-gp" {
  name                = "sec-gp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}


# Cria NIC
resource "azurerm_network_interface" "net-int" {
  name                = "net-int"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "net-int-configuration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }

}

resource "azurerm_network_interface_security_group_association" "nicNSG_http" {
  network_interface_id      = azurerm_network_interface.net-int.id
  network_security_group_id = azurerm_network_security_group.sec-gp.id
}

# Cria nome genérico para a chave ssh
resource "random_pet" "ssh_key_name" {
  #depends_on = [azurerm_network_interface.nic]
  prefix    = "ssh"
  separator = ""
}

# Gera uma chave pública e uma privada
resource "azapi_resource_action" "ssh_public_key_gen" {
  type        = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  resource_id = azapi_resource.ssh_public_key.id
  action      = "generateKeyPair"
  method      = "POST"

  response_export_values = ["publicKey", "privateKey"]
}

# Associa o nome da chave criada aleatoriamente com a chave pública
resource "azapi_resource" "ssh_public_key" {
  type      = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  name      = random_pet.ssh_key_name.id
  location  = azurerm_resource_group.rg.location
  parent_id = azurerm_resource_group.rg.id
}

# Salva a chave pública no diretório principal
resource "local_file" "private_key" {
  content         = azapi_resource_action.ssh_public_key_gen.output.privateKey
  filename        = "private_key.pem"
  file_permission = "0600"
}

# Cria a máquina virtual
resource "azurerm_linux_virtual_machine" "student-vm" {
  name                  = "student-vm"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.net-int.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name  = "studentVM"
  admin_username = var.username
  admin_password = var.vm_admin_password

  admin_ssh_key {
    username   = var.username
    public_key = azapi_resource_action.ssh_public_key_gen.output.publicKey
  }
}

# Gerar um inventario das VMs
resource "local_file" "inventory" {
  #depends_on = [azurerm_linux_virtual_machine.student-vm]
  content = templatefile("inventory.tpl", {
    web_ip       = azurerm_linux_virtual_machine.student-vm.public_ip_address,
    ansible_user = var.username
  })
  filename = "./ansible/inventory.ini"
}