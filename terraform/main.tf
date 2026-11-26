// Prefixo dos nomes e tags aplicadas em todos os recursos
locals {
  prefix = "pm04-${var.environment}"

  tags = {
    projeto        = "pm04-todo-app"
    ambiente       = var.environment
    gerenciado_por = "terraform"
  }
}

// RG da infraestrutura separado do rg-pm04, que guarda o state
resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.prefix}"
  location = var.location
  tags     = local.tags
}

// Rede

// Rede virtual 10.0.0.0/16 onde ficam as duas VMs
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${local.prefix}"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

// Subnet da VM da aplicação (10.0.1.0/24)
resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.app_subnet_cidr]
}

// Subnet privada da VM do banco (10.0.2.0/24)
resource "azurerm_subnet" "db" {
  name                 = "snet-db"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.db_subnet_cidr]
}

// NSG da aplicação: SSH para o Ansible e HTTP para os visitantes
resource "azurerm_network_security_group" "app" {
  name                = "nsg-app-${local.prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "https"
    priority                   = 115
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

// NSG do banco: MongoDB só a partir da subnet da aplicação, resto bloqueado
resource "azurerm_network_security_group" "db" {
  name                = "nsg-db-${local.prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "mongodb-da-app"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "27017"
    source_address_prefix      = var.app_subnet_cidr
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "mongodb-bloqueado"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "27017"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

// Aplica o NSG da aplicação na subnet da aplicação
resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

// Aplica o NSG do banco na subnet do banco
resource "azurerm_subnet_network_security_group_association" "db" {
  subnet_id                 = azurerm_subnet.db.id
  network_security_group_id = azurerm_network_security_group.db.id
}

// Placas de rede sem IP público; entrada só pelo Load Balancer

// Placa de rede da VM da aplicação, só IP privado
resource "azurerm_network_interface" "app" {
  name                = "nic-app-${local.prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Dynamic"
  }
}

// Placa de rede da VM do banco, só IP privado
resource "azurerm_network_interface" "db" {
  name                = "nic-db-${local.prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.db.id
    private_ip_address_allocation = "Dynamic"
  }
}

// VMs

// VM da aplicação: Nginx + React + API Node, tamanho vem do parâmetro instance_type
resource "azurerm_linux_virtual_machine" "app" {
  name                            = var.instance_name
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = var.instance_type
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.app.id]
  tags                            = merge(local.tags, { funcao = "aplicacao" })

  admin_ssh_key {
    username   = var.admin_username
    public_key = trimspace(var.ssh_public_key)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

// VM do banco: MongoDB isolado, sem IP público
resource "azurerm_linux_virtual_machine" "db" {
  name                            = "${var.instance_name}-db"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = var.db_instance_type
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.db.id]
  tags                            = merge(local.tags, { funcao = "banco" })

  admin_ssh_key {
    username   = var.admin_username
    public_key = trimspace(var.ssh_public_key)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

// Load Balancer: único IP público do ambiente

// IP público fixo do Load Balancer, é o endereço que o usuário acessa
resource "azurerm_public_ip" "lb" {
  name                = "pip-lb-${local.prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

// Load Balancer Standard com o IP público no frontend
resource "azurerm_lb" "lb" {
  name                = "lb-${local.prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  tags                = local.tags

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

// Pool com as duas VMs só para saída à internet (apt e docker pull)
resource "azurerm_lb_backend_address_pool" "pool" {
  name            = "pool-vms"
  loadbalancer_id = azurerm_lb.lb.id
}

// Coloca a VM da aplicação no pool de saída
resource "azurerm_network_interface_backend_address_pool_association" "app" {
  network_interface_id    = azurerm_network_interface.app.id
  ip_configuration_name   = "ipconfig"
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool.id
}

// Coloca a VM do banco no pool de saída
resource "azurerm_network_interface_backend_address_pool_association" "db" {
  network_interface_id    = azurerm_network_interface.db.id
  ip_configuration_name   = "ipconfig"
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool.id
}

// Libera saída à internet das VMs pelo IP do Load Balancer
resource "azurerm_lb_outbound_rule" "saida" {
  name                    = "saida-internet"
  loadbalancer_id         = azurerm_lb.lb.id
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool.id

  frontend_ip_configuration {
    name = "frontend"
  }
}

// HTTP 80 do LB vai só para a VM da aplicação
resource "azurerm_lb_nat_rule" "http_app" {
  name                           = "http-app"
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend"
}

// Liga a regra HTTP na placa de rede da VM da aplicação
resource "azurerm_network_interface_nat_rule_association" "http_app" {
  network_interface_id  = azurerm_network_interface.app.id
  ip_configuration_name = "ipconfig"
  nat_rule_id           = azurerm_lb_nat_rule.http_app.id
}

// HTTPS 443 do LB vai para a VM da aplicação (Caddy + Let's Encrypt via nip.io)
resource "azurerm_lb_nat_rule" "https_app" {
  name                           = "https-app"
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "frontend"
}

// Liga a regra HTTPS na placa de rede da VM da aplicação
resource "azurerm_network_interface_nat_rule_association" "https_app" {
  network_interface_id  = azurerm_network_interface.app.id
  ip_configuration_name = "ipconfig"
  nat_rule_id           = azurerm_lb_nat_rule.https_app.id
}

// SSH da VM da aplicação pela porta 2222 do LB
resource "azurerm_lb_nat_rule" "ssh_app" {
  name                           = "ssh-app"
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 2222
  backend_port                   = 22
  frontend_ip_configuration_name = "frontend"
}

// Liga a regra SSH 2222 na placa de rede da VM da aplicação
resource "azurerm_network_interface_nat_rule_association" "ssh_app" {
  network_interface_id  = azurerm_network_interface.app.id
  ip_configuration_name = "ipconfig"
  nat_rule_id           = azurerm_lb_nat_rule.ssh_app.id
}

// SSH da VM do banco pela porta 2223 do LB; a 27017 nunca é publicada
resource "azurerm_lb_nat_rule" "ssh_db" {
  name                           = "ssh-db"
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  protocol                       = "Tcp"
  frontend_port                  = 2223
  backend_port                   = 22
  frontend_ip_configuration_name = "frontend"
}

// Liga a regra SSH 2223 na placa de rede da VM do banco
resource "azurerm_network_interface_nat_rule_association" "ssh_db" {
  network_interface_id  = azurerm_network_interface.db.id
  ip_configuration_name = "ipconfig"
  nat_rule_id           = azurerm_lb_nat_rule.ssh_db.id
}
