output "keyring_id" {
  description = "Id del llavero"
  value       = google_kms_key_ring.this.id
}

output "key_ids" {
  description = "Mapa nombre de llave => id"
  value       = { for k, v in google_kms_crypto_key.this : k => v.id }
}
