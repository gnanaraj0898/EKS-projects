// In a file named 'backend.tf'

terraform {
  backend "s3" {
    // Required parameters
    bucket = "terraform-state-backup-am" // Replace with your S3 bucket name
    key    = "terraform.tfstate" // The primary state file path in the bucket
    region = "us-east-1"                           // The AWS region your bucket is in

    // Enable S3 native state locking (requires Terraform >= 1.10)
    use_lockfile = true

    // Optional but highly recommended:
    //encrypt      = true // Encrypts the state file at rest
  }
}
