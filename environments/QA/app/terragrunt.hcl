terraform {
  # PICK ONE SOURCE
    source = "../../../Modules/app-with-external-modules/"
    # source = "../../../Modules/app-custom-module/"
}

include "root" {
    path = find_in_parent_folders()
}

inputs = {
    instance_replica_count = 1
    environment = "QA"
    instance_type_db_server="t3.medium"
    instance_type_web_server="t3.small"    
}

generate "provider" {
  path = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
provider "aws" {
  shared_credentials_files = [PROVIDE PATH TO YOUR CREDENTIALS or configure provider credentials differntly]
  region = "[REGION NAME]"
  profile = "[OPTIONAL PROFILE if PROFILES ARE USED"
}
EOF
}