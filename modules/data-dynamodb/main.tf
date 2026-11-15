resource "aws_dynamodb_table" "audit" {
  name         = var.name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "clinic_id"
  range_key    = "event_time"

  attribute {
    name = "clinic_id"
    type = "S"
  }

  attribute {
    name = "event_time"
    type = "S"
  }

  # Old audit rows expire when expires_at (epoch seconds) passes
  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  # Restore path for the disaster recovery drill
  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  deletion_protection_enabled = var.deletion_protection
}
