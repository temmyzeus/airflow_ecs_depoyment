terraform {
  backend "s3" {
    bucket       = "terraform-state-files-409021554022"
    key          = "production/airflow_ecr_deployment/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
  }
}
