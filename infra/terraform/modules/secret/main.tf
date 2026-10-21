resource "kubernetes_secret" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = var.labels
  }

  # The provider maps `data` to the Kubernetes StringData field, so the values
  # are written in plaintext here and the API server base64-encodes them on
  # admission. Do NOT base64encode() them: that would double-encode them.
  data = {
    DB_USER                 = var.db_user
    DB_PASSWORD             = var.db_password
    ACTIVEMQ_USER           = var.activemq_user
    ACTIVEMQ_PASSWORD       = var.activemq_password
    TRANSFORM_SHARED_SECRET = var.transform_shared_secret
    ALFRESCO_ADMIN_USER     = var.alfresco_admin_user
    ALFRESCO_ADMIN_PASSWORD = var.alfresco_admin_password

    # The keystore passwords belong to the keystore shipped inside the
    # Alfresco image. They are kept in the Secret so they never appear in
    # the Deployment spec.
    METADATA_KEYSTORE_PASSWORD          = var.metadata_keystore_password
    METADATA_KEYSTORE_METADATA_PASSWORD = var.metadata_keystore_metadata_password
  }
}
