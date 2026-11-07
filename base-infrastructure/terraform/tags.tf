locals {
  base_tags = {
    DeployedBy  = "GO Team"
    Owner       = "IM Team"
    Contact     = "im@"
    Service     = "GO"
    Ticket      = "github.com/IFRCGo/go-api/issues/1771"
    Environment = var.environment
  }
}
