output "bucket_name" {
  description = "Name of the ObjectStorage bucket"
  value       = stackit_objectstorage_bucket.data.name
}

output "bucket_url" {
  description = "Bucket URL"
  value       = stackit_objectstorage_bucket.data.url
}

output "postgres_instance_id" {
  description = "Postgres Flex instance ID"
  value       = stackit_postgresflex_instance.db.instance_id
}

output "postgres_version" {
  description = "Provisioned Postgres major version"
  value       = stackit_postgresflex_instance.db.version
}
