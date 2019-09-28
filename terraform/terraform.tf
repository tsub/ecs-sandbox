terraform {
  required_version = ">= 0.12"

  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "tsub-sandbox"

    workspaces {
      name = "ecs-sandbox"
    }
  }
}
