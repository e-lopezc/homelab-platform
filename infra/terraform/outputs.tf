# Node inventory for the next step (Ansible / k3s bootstrap), so the inventory is
# derived from Terraform state instead of a hand-maintained hosts file. IPs are
# static (assigned via cloud-init), so we read them straight from the nodes map
# with the CIDR suffix stripped.
output "nodes" {
  description = "Provisioned k3s nodes keyed by name, with role and bare IP."
  value = {
    for name, cfg in var.nodes : name => {
      role = cfg.role
      ip   = split("/", cfg.ip)[0]
    }
  }
}

# Convenience splits for building an Ansible inventory (server vs agents).
output "server_ips" {
  description = "IPs of nodes with role = server."
  value       = [for cfg in var.nodes : split("/", cfg.ip)[0] if cfg.role == "server"]
}

output "agent_ips" {
  description = "IPs of nodes with role = agent."
  value       = [for cfg in var.nodes : split("/", cfg.ip)[0] if cfg.role == "agent"]
}
