terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.26"
    }
  }

}

#Para nao ficar pedindo a senha toda hora
provider "azurerm" {
  skip_provider_registration =true
   features {}
}


#Para criar o grupo 
resource "azurerm_resource_group" "rg-aulainfra" {
  name     = "group_Danilo"
  location = "eastus"
}

#Para criar a rede virtual e sub-rede
resource "azurerm_virtual_network" "vnet-aulainfra" {
  name                = "vnetaula"
  location            = azurerm_resource_group.rg-aulainfra.location
  resource_group_name = azurerm_resource_group.rg-aulainfra.name
  address_space       = ["10.80.0.0/16"]
  
  tags = {
    environment = "aula"
  }
depends_on = [ azurerm_resource_group.rg-aulainfra ]
  
}

resource "azurerm_subnet" "subnet-aula" {
  name                 = "subnetaula"
  resource_group_name  = azurerm_resource_group.rg-aulainfra.name
  virtual_network_name = azurerm_virtual_network.vnet-aulainfra.name
  address_prefixes     = ["10.80.4.0/24"]

depends_on = [ azurerm_resource_group.rg-aulainfra, azurerm_virtual_network.vnet-aulainfra ]
 
}


#para criar um Ip publico
resource "azurerm_public_ip" "publicip-aula" {
  name                = "publicIpAula"
  resource_group_name = azurerm_resource_group.rg-aulainfra.name
  location            = azurerm_resource_group.rg-aulainfra.location
  allocation_method   = "Static"
 
 
}

#Para criar o Firewell e liberar as portas
resource "azurerm_network_security_group" "networksecuritygroup-aula" {
  name                = "networksecurityGroup"
  location            = azurerm_resource_group.rg-aulainfra.location
  resource_group_name = azurerm_resource_group.rg-aulainfra.name

  security_rule {
    name                       = "ssh"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"    #aqui libera as porta
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

security_rule {
        name                       = "HTTPInbound"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "8080"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "mysql"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3306"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "aula infra"
    }
  depends_on = [ azurerm_resource_group.rg-aulainfra ]
}

#Para criar a placa de rede
resource "azurerm_network_interface" "ni_aula" {
  name                = "networkInterface-aula"
  location            = azurerm_resource_group.rg-aulainfra.location
  resource_group_name = azurerm_resource_group.rg-aulainfra.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet-aula.id
    private_ip_address_allocation = "Static"
     private_ip_address           = "10.80.4.11"
    public_ip_address_id = azurerm_public_ip.publicip-aula.id
  }

depends_on = [ azurerm_resource_group.rg-aulainfra, azurerm_subnet.subnet-aula, azurerm_public_ip.publicip-aula ]

}

#vincula placa de rede com firewell
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.ni_aula.id
  network_security_group_id = azurerm_network_security_group.networksecuritygroup-aula.id
}

#Maquina Virtual
# resource "azurerm_linux_virtual_machine" "MaquinaVirtual-aula" {
#   name                = "example-machine"
#   resource_group_name = azurerm_resource_group.rg-aulainfra.name
#   location            = azurerm_resource_group.rg-aulainfra.location
#   size                = "Standard_F2"
#   admin_username      = "adminuser"
#   admin_password      = "Aula@infra02"
#   disable_password_authentication = false

#   network_interface_ids = [
#     azurerm_network_interface.ni_aula.id,
#   ]

 
 

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }

#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "16.04-LTS"
#     version   = "latest"
#   }
# }


#MAquina virtual para Exercicio
#criar maquina e subir MySql

resource "azurerm_storage_account" "storage_aula_db" {
    name                        = "storageauladb"
    resource_group_name         = azurerm_resource_group.rg-aulainfra.name
    location                    = azurerm_resource_group.rg-aulainfra.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "aula infra"
    }

    depends_on = [ azurerm_resource_group.rg-aulainfra ]
}

resource "azurerm_linux_virtual_machine" "vm_aula_db" {
    name                  = "myVMDB"
    location              = azurerm_resource_group.rg-aulainfra.location
    resource_group_name   = azurerm_resource_group.rg-aulainfra.name
    network_interface_ids = [azurerm_network_interface.ni_aula.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDBDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "myvmdb"
    admin_username      = "adminuser"
    admin_password      = "Aula@infra02"
    disable_password_authentication = false

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.storage_aula_db.primary_blob_endpoint
    }

    tags = {
        environment = "aula infra"
    }

    depends_on = [ azurerm_resource_group.rg-aulainfra, azurerm_network_interface.ni_aula, azurerm_storage_account.storage_aula_db, azurerm_public_ip.publicip-aula ]
}

resource "time_sleep" "wait_30_seconds_db" {
  depends_on = [azurerm_linux_virtual_machine.vm_aula_db]
  create_duration = "30s"
}

data "azurerm_public_ip" "ip_aula_data_db" {
  name                = azurerm_public_ip.publicip-aula.name
  resource_group_name = azurerm_resource_group.rg-aulainfra.name
}

resource "null_resource" "upload_db" {
    provisioner "file" {
        connection {
            type = "ssh"
            user = "adminuser"
            password = "Aula@infra02"
            host = data.azurerm_public_ip.ip_aula_data_db.ip_address
        }
        source = "mysql"
        destination = "/home/adminuser"
    }

    depends_on = [ time_sleep.wait_30_seconds_db ]
}

resource "null_resource" "deploy_db" {
    triggers = {
        order = null_resource.upload_db.id
    }
    provisioner "remote-exec" {
        connection {
            type = "ssh"
            user =   "adminuser"
            password = "Aula@infra02"
            host = data.azurerm_public_ip.ip_aula_data_db.ip_address
        }
        inline = [
            "sudo apt-get update",
            "sudo apt-get install -y mysql-server-5.7",
            "sudo mysql < /home/adminuser/mysql/script/user.sql",
            "sudo mysql < /home/adminuser/mysql/script/schema.sql",
            "sudo mysql < /home/adminuser/mysql/script/data.sql",
            "sudo cp -f /home/adminuser/mysql/mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf",
            "sudo service mysql restart",
            "sleep 20",
        ]
    }
}