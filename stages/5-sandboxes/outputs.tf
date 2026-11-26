output "sandboxes" {
  description = "Sandboxes vigentes"
  value = {
    for k, s in module.sandbox : k => {
      project_id         = s.project_id
      subnet_cidr        = s.subnet_cidr
      service_account    = s.service_account
      monthly_budget_usd = s.monthly_budget_usd
      profile            = local.teams[k].profile
      size               = local.teams[k].size
      expires            = local.teams[k].expires
    }
  }
}

output "catalog" {
  description = "Perfiles y tallas disponibles"
  value       = { for k, p in local.catalog.profiles : k => p.description }
}
