resource "google_kms_key_ring" "this" {
  name     = var.keyring_name
  project  = var.project_id
  location = var.location
}

# Una llave por servicio: permite revocar un servicio sin afectar a los demas.
resource "google_kms_crypto_key" "this" {
  for_each        = var.keys
  name            = each.key
  key_ring        = google_kms_key_ring.this.id
  rotation_period = var.rotation_period
}

# Los agentes de servicio necesitan usar la llave para cifrar con CMEK.
# Las claves del mapa son estaticas para que for_each se conozca en el plan.
resource "google_kms_crypto_key_iam_member" "encrypter" {
  for_each      = var.encrypters
  crypto_key_id = google_kms_crypto_key.this[each.value.key].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = each.value.member
}
