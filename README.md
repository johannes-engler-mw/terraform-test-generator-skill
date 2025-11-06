# Terraform Test Generator Skill

A Claude Code skill for generating Terraform test cases following HashiCorp's official testing standards.

## What It Does

This skill generates Terraform test suites by:

1. Analyzing your Terraform code and detecting providers
2. Generating appropriate test files (unit, integration, mock, validation, compliance)
3. Providing templates for multi-cloud and advanced testing patterns
4. Creating test documentation (COVERAGE.md, README.md)

The skill includes 7 test templates covering everything from basic unit tests to complex multi-provider scenarios, with built-in anti-pattern detection and cloud-specific best practices.

## Installation

```bash
# From marketplace
/plugin marketplace add johannes-engler-mw/terraform-test-generator-skill
/plugin install terraform-test-generator

# Or from GitHub URL
/plugin marketplace add https://github.com/johannes-engler-mw/terraform-test-generator-skill.git
/plugin install terraform-test-generator

# Or manually (clone first, then add local path)
/plugin marketplace add ./terraform-test-generator-skill
/plugin install terraform-test-generator
```

## Usage

```bash
/skill terraform-test-generator
```

The skill will analyze your Terraform module, identify providers, and generate appropriate test files with documentation.

## Supported Providers

- **AWS**: Resource mocking, data sources, IAM policies
- **Azure**: UUID handling, subscription/resource group patterns
- **GCP**: Project ID management, service account handling
- **Multi-cloud**: Cross-provider and multi-region testing

## Test Templates

The skill includes 7 test templates:

| Template | Type | Purpose |
|----------|------|---------|
| **unit-test-template.hcl** | Unit | Fast tests with mock providers, no real infrastructure |
| **integration-test-template.hcl** | Integration | Real provider interactions, validates actual resource creation |
| **mock-test-template.hcl** | Mock | Override patterns for data sources and external dependencies |
| **validation-test-template.hcl** | Validation | Test variable validations, preconditions, postconditions |
| **compliance-test-template.hcl** | Compliance | Security, tagging, naming conventions, cost optimization |
| **advanced-patterns-template.hcl** | Advanced | Dynamic blocks, for expressions, conditional logic |
| **multi-provider-template.hcl** | Multi-cloud | Cross-provider and multi-region testing |

Each template includes inline documentation, examples, and anti-pattern avoidance.

## Repository Structure

```
terraform-test-generator-skill/
├── .claude-plugin/
│   ├── plugin.json           # Plugin metadata
│   └── marketplace.json      # Marketplace configuration
├── skills/
│   └── terraform-test-generator/
│       ├── skill.md          # Main skill definition
│       ├── templates/        # HCL test templates
│       │   ├── unit-test-template.hcl           # Core: Configuration testing
│       │   ├── integration-test-template.hcl    # Core: Real resource testing
│       │   ├── mock-test-template.hcl           # Core: Override patterns
│       │   ├── validation-test-template.hcl     # Advanced: expect_failures
│       │   ├── compliance-test-template.hcl     # Advanced: Security/compliance
│       │   ├── advanced-patterns-template.hcl   # Advanced: Complex scenarios
│       │   └── multi-provider-template.hcl      # Advanced: Multi-cloud
│       └── reference/        # Best practices and patterns
│           ├── anti-patterns.md
│           ├── cloud-providers-aws.md
│           ├── cloud-providers-azure.md
│           ├── cloud-providers-gcp.md
│           ├── compliance-patterns.md
│           ├── syntax-examples.md
│           ├── validation-patterns.md
│           └── verification-checklist.md
├── example/                  # Example Terraform module with tests
├── README.md
└── LICENSE
```

## Requirements

- Claude Code
- Terraform 1.6.0 or higher
- Terraform configuration files

## Example Output

```
your-module/
├── main.tf
├── variables.tf
├── outputs.tf
├── tests/
│   ├── basic_unit_test.tftest.hcl
│   ├── full_deployment_integration.tftest.hcl
│   ├── data_sources.tfmock.hcl
│   ├── input_validation.tftest.hcl
│   ├── README.md
│   └── COVERAGE.md
```

## Credits

This skill is based on the original work by [Dharani Sowndharya](https://github.com/dharani-sowndharya). The original repository can be found at:
<https://github.com/dharani-sowndharya/terraform-test-mcp>

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License - see [LICENSE](LICENSE) file for details

## Resources

- [HashiCorp Terraform Testing Documentation](https://developer.hashicorp.com/terraform/language/tests)
- [Terraform Test Framework Guide](https://developer.hashicorp.com/terraform/tutorials/configuration-language/test)
- [Claude Code Documentation](https://docs.claude.com/en/docs/claude-code)

## Support

For issues, questions, or suggestions, please open an issue on GitHub.

---

**Note**: This skill generates test code but does not execute Terraform commands. You'll need to run the generated tests using `terraform test` in your environment.
