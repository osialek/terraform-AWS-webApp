remote_state {
  # CHANGE BACKEND TYPE IF NEEDED
  backend = "s3"
  generate = {
    path = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket         = "[YOUR-BUCKET-NAME]"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "[REGION YOU WANT TO USE]"
  }
}
