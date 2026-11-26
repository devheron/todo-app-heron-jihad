// IP público do Load Balancer
output "lb_public_ip" {
  description = "IP público do Load Balancer"
  value       = azurerm_public_ip.lb.ip_address
}

// URL HTTPS do ToDo App via nip.io (resolve direto para o IP do Load Balancer)
output "app_url" {
  description = "Endereço HTTPS do ToDo App"
  value       = "https://${azurerm_public_ip.lb.ip_address}.nip.io"
}

// IP interno da VM da aplicação
output "app_private_ip" {
  description = "IP privado da VM da aplicação"
  value       = azurerm_network_interface.app.private_ip_address
}

// IP interno da VM do banco, usado na conexão da API com o MongoDB
output "db_private_ip" {
  description = "IP privado da VM do banco"
  value       = azurerm_network_interface.db.private_ip_address
}

// Comando SSH pronto para a VM da aplicação
output "ssh_app" {
  description = "Acesso administrativo à VM da aplicação"
  value       = "ssh -i ~/.ssh/pm04 -p ${azurerm_lb_nat_rule.ssh_app.frontend_port} ${var.admin_username}@${azurerm_public_ip.lb.ip_address}"
}

// Comando SSH pronto para a VM do banco
output "ssh_db" {
  description = "Acesso administrativo à VM do banco"
  value       = "ssh -i ~/.ssh/pm04 -p ${azurerm_lb_nat_rule.ssh_db.frontend_port} ${var.admin_username}@${azurerm_public_ip.lb.ip_address}"
}

// Inventory do Ansible gerado a partir dos recursos criados
output "ansible_inventory" {
  description = "Conteúdo de ansible/inventory/hosts.yml"
  value       = <<-EOT
    all:
      vars:
        ansible_user: ${var.admin_username}
        ansible_ssh_private_key_file: ~/.ssh/pm04
      children:
        app:
          hosts:
            app1:
              ansible_host: ${azurerm_public_ip.lb.ip_address}
              ansible_port: ${azurerm_lb_nat_rule.ssh_app.frontend_port}
        db:
          hosts:
            db1:
              ansible_host: ${azurerm_public_ip.lb.ip_address}
              ansible_port: ${azurerm_lb_nat_rule.ssh_db.frontend_port}
  EOT
}
