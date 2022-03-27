terraform {
  backend "remote" {
    organization = "brauliojbb"

    workspaces {
      name = "cli-workspace"
    }
  }
}
