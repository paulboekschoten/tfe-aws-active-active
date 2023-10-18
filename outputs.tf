output "public_ip" {
  value = aws_eip.eip_tfe.public_ip
}

output "tfe_login" {
  description = "Url for TFE login."
  value       = "https://${local.fqdn}"
}

output "release_sequence" {
  description = "Installed release number of TFE."
  value       = var.release_sequence
}