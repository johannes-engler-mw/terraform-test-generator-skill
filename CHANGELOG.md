# Changelog

All notable changes to the Terraform Test Generator Skill will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-05

### Added
- Initial release of Terraform Test Generator skill
- Comprehensive 10-step workflow for generating Terraform test suites
- Multi-cloud provider support (AWS, Azure, GCP)
- Unit test generation with mock providers
- Integration test generation with real providers
- Mock test generation with override patterns
- Validation test generation for input/output testing
- Compliance test generation based on security requirements
- Anti-pattern detection and prevention
- Verification checklist for quality assurance
- Cost and safety warnings for integration tests
- Resource name conflict prevention guidance
- Built-in quality gates and error handling
- Comprehensive documentation:
  - Anti-patterns reference guide
  - Cloud provider-specific patterns (AWS, Azure, GCP)
  - Syntax examples and templates
  - Validation patterns
  - Compliance patterns
  - Verification checklist
- HCL test templates:
  - Unit test template
  - Integration test template
  - Mock test template
- Support for Terraform >= 1.6.0
- Automatic test file organization in `tests/` directory
- Coverage report generation (COVERAGE.md)
- Test documentation generation (README.md)

### Features
- Intelligent defaults for variable values
- Automatic provider detection
- Data source identification and mocking
- Set-type attribute handling with for expressions
- Proper command selection (plan vs apply)
- UUID format validation for Azure resources
- Multi-line condition prevention
- TodoWrite integration for progress tracking

### Documentation
- Comprehensive README with installation and usage instructions
- MIT License with attribution to original author
- Repository structure documentation
- Example test structures
- Best practices enforcement
- HashiCorp official testing standards compliance

### Based On
- Original work by [Dharani Sowndharya](https://github.com/dharani-sowndharya)
- Repository: https://github.com/dharani-sowndharya/terraform-test-mcp

---

## Versioning Strategy

This project uses [Semantic Versioning](https://semver.org/):
- **MAJOR** version for incompatible API changes
- **MINOR** version for added functionality in a backward compatible manner
- **PATCH** version for backward compatible bug fixes

## Categories

- **Added**: New features
- **Changed**: Changes in existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Vulnerability fixes
