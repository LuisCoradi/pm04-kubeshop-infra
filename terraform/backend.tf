# State remoto no S3, com trava nativa (use_lockfile) e criptografia.
# bucket, key e region são passados pela pipeline em `terraform init
# -backend-config=...` (scripts/tf-init.sh). Cada ambiente usa uma key
# própria: kubeshop/<ambiente>/terraform.tfstate.
terraform {
  backend "s3" {
    use_lockfile = true
    encrypt      = true
  }
}
