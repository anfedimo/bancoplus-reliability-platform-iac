plugin "terraform" {
  enabled = true
  preset  = "recommended"
  version = "0.15.0"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}

rule "terraform_documented_variables" { enabled = true }
rule "terraform_documented_outputs" { enabled = false }
rule "terraform_naming_convention" { enabled = true }
