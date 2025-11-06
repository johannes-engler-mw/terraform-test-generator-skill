# Terraform Test Generator Skill

A comprehensive Claude Code skill for generating high-quality Terraform test cases following HashiCorp's official testing standards.

## Features

- **7 Comprehensive Test Templates**: Core (unit, integration, mock) and advanced (validation, compliance, advanced patterns, multi-provider) templates
- **Multi-Cloud Support**: Built-in patterns and best practices for AWS, Azure, GCP, and multi-cloud scenarios
- **Anti-Pattern Detection**: Automatically identifies and avoids common testing pitfalls
- **Advanced Testing Patterns**: For expressions, dynamic blocks, conditional logic, and complex scenarios
- **Security & Compliance**: Built-in templates for testing encryption, tagging, network security, and compliance
- **Built-in Quality Assurance**: Verification checkpoints ensure test reliability
- **Production-Ready**: Based on HashiCorp's official testing framework and best practices

## What This Skill Does

The Terraform Test Generator skill guides you through a comprehensive workflow to create production-ready test suites:

1. Collects requirements with intelligent defaults
2. Analyzes your Terraform code and detects providers
3. Reviews anti-patterns to prevent common failures
4. Selects appropriate test commands (plan vs apply)
5. Generates unit tests with proper mock providers
6. Creates integration tests with real provider interactions
7. Builds mock tests with override patterns
8. Generates validation tests (expect_failures) when validation blocks exist
9. Creates compliance tests for security and best practices
10. Applies advanced patterns for complex scenarios (optional)
11. Supports multi-cloud testing patterns (optional)
12. Produces comprehensive documentation (COVERAGE.md, README.md)

## Installation

### Via Claude Code Marketplace

Install directly from the marketplace using:

```bash
/plugin marketplace add johannes-engler-mw/terraform-test-generator-skill
```

Then install the plugin:

```bash
/plugin install terraform-test-generator
```

### Via GitHub URL

```bash
/plugin marketplace add https://github.com/johannes-engler-mw/terraform-test-generator-skill.git
/plugin install terraform-test-generator
```

### Manual Installation

1. Clone this repository:

   ```bash
   git clone https://github.com/johannes-engler-mw/terraform-test-generator-skill.git
   ```

2. Add the marketplace locally:

   ```bash
   /plugin marketplace add ./terraform-test-generator-skill
   ```

3. Install the plugin:

   ```bash
   /plugin install terraform-test-generator
   ```

## Usage

Once installed, invoke the skill in Claude Code:

```bash
/skill terraform-test-generator
```

The skill will guide you through an interactive process to:

- Understand your Terraform module structure
- Identify cloud providers in use
- Determine test coverage requirements
- Generate appropriate test files
- Create documentation and coverage reports

## Supported Cloud Providers

### AWS

- Resource mocking patterns
- Data source handling
- IAM policy testing
- Best practices for AWS-specific resources

### Azure

- UUID handling for Azure resources
- Subscription and resource group patterns
- Azure-specific validation tests
- Best practices for Azure resources

### GCP

- Project ID management
- GCP-specific mocking patterns
- Service account handling
- Best practices for GCP resources

## Test Types Generated

### Unit Tests

- Fast, isolated tests using mock providers
- No real infrastructure created
- Focus on Terraform logic and expressions

### Integration Tests

- Real provider interactions
- Validates actual resource creation
- Includes cost warnings and safety checks

### Mock Tests

- Override files for data sources
- External dependency simulation
- Safe testing without real resources

### Validation Tests

- Input variable validation
- Output value verification
- Edge case handling

### Compliance Tests

- Security policy enforcement
- Tagging requirements
- Resource naming conventions
- Cost optimization checks

## Test Templates

The skill includes 7 comprehensive test templates:

### Core Templates

| Template | Purpose | Use Case |
|----------|---------|----------|
| **unit-test-template.hcl** | Configuration testing with mock providers | Test Terraform logic without creating resources |
| **integration-test-template.hcl** | Real resource creation and testing | Verify actual infrastructure creation |
| **mock-test-template.hcl** | Override patterns for data/modules/resources | Test with mocked external dependencies |

### Advanced Templates

| Template | Purpose | Use Case |
|----------|---------|----------|
| **validation-test-template.hcl** | Testing validations with expect_failures | Test variable validations, preconditions, postconditions |
| **compliance-test-template.hcl** | Security and compliance testing | Test encryption, tagging, network security |
| **advanced-patterns-template.hcl** | Complex scenarios and patterns | Test dynamic blocks, for expressions, conditional logic |
| **multi-provider-template.hcl** | Multi-cloud and multi-region testing | Test AWS+Azure, AWS+GCP, multi-region setups |

Each template includes:
- Comprehensive inline documentation
- Multiple real-world examples
- Best practices and anti-pattern avoidance
- Ready-to-customize code snippets

## Key Features

### Anti-Pattern Detection

The skill includes comprehensive anti-pattern documentation covering:

- Resource naming conflicts
- Missing provider blocks in tests
- Incorrect mock provider usage
- Data source misconfigurations

### Verification Checklist

Quality gates ensure:

- Proper test structure
- Correct provider configuration
- Valid HCL syntax
- Appropriate test coverage
- Documentation completeness

### Cost and Safety Awareness

- Warns about integration test costs
- Provides cleanup guidance
- Includes safety checks for destructive operations
- Recommends CI/CD integration practices

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
├── example/                  # Example Terraform module with comprehensive tests
├── README.md
└── LICENSE
```

## Requirements

- Claude Code (latest version)
- Terraform 1.6.0 or higher (for optimal test framework support)
- Project using Terraform configuration files

## Examples

The skill will generate test files like:

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

## Best Practices

The skill enforces HashiCorp's official best practices:

- Proper test file naming conventions
- Correct use of mock providers
- Appropriate test isolation
- Documentation standards
- Coverage reporting

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
