# tflint --init installs the plugins. tflint --recursive reads the .tflint.hcl of each module
# directory, so pass this one explicitly: tflint --recursive --config "$PWD/.tflint.hcl".
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.50.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
