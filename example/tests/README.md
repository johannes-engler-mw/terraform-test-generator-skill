# Terraform Tests

This directory contains comprehensive test suites for the AWS infrastructure Terraform module.

## Prerequisites

- **Terraform >= 1.6.0** (native testing framework required)
- **AWS CLI** configured with valid credentials
- **Proper IAM permissions** for creating test resources

## Test Organization

### Unit Tests (Mock Providers - FREE)

These tests use mock providers and `command = plan` to test configuration logic without creating real resources.

- **`unit_networking.tftest.hcl`** - VPC and subnet configuration tests
- **`unit_security.tftest.hcl`** - Security group configuration tests
- **`unit_storage.tftest.hcl`** - S3 bucket and KMS configuration tests
- **`unit_compute.tftest.hcl`** - EC2 instance configuration tests

### Integration Tests (Real Resources - COSTS MONEY)

⚠️ **WARNING**: These tests create REAL AWS resources and WILL incur costs!

- **`integration_full_deployment.tftest.hcl`** - End-to-end infrastructure deployment tests

### Mock Tests (Data Source Overrides - FREE)

These tests use `override_data` to mock external data sources for testing different scenarios.

- **`mock_data_sources.tftest.hcl`** - Tests with mocked availability zones and AMI data

### Validation Tests (FREE)

These tests verify input validation rules and lifecycle preconditions using `expect_failures`.

- **`validation_variable_rules.tftest.hcl`** - Tests for all variable validation blocks (13 validations)
- **`validation_preconditions.tftest.hcl`** - Tests for resource preconditions

### Compliance Tests (FREE)

These tests verify security and operational best practices.

- **`compliance_security.tftest.hcl`** - Encryption, S3 security, volume encryption
- **`compliance_tagging.tftest.hcl`** - Required tagging for all resources

## Running Tests

### Run All Tests

```bash
terraform test
```

### Run Specific Test Types

```bash
# Unit tests only (safe, fast, free)
terraform test -filter=unit_*

# Mock tests only (safe, free)
terraform test -filter=mock_*

# Validation tests only (safe, free)
terraform test -filter=validation_*

# Compliance tests only (safe, free)
terraform test -filter=compliance_*

# Integration tests (WARNING: creates real resources)
terraform test -filter=integration_*
```

### Run a Specific Test File

```bash
terraform test tests/unit_networking.tftest.hcl
```

### Verbose Output

```bash
terraform test -verbose
```

### Keep Resources After Test (for debugging)

```bash
terraform test -cleanup=false
```

⚠️ **Important**: Remember to manually destroy resources if using `-cleanup=false`!

## ⚠️ Cost & Safety Considerations

### WARNING: Integration Tests Create Real Resources

Integration tests use `command = apply` and will:
- Create REAL AWS resources (VPC, subnets, S3 buckets, KMS keys, EC2 instances)
- **INCUR ACTUAL COSTS** on your AWS account
- Potentially clash with existing resources if not properly configured

### Before Running Integration Tests

1. **Verify test variables** in the test files use test-specific values:
   - `project_name` uses test prefixes (e.g., "test-tf-gen-skill")
   - `environment` is set to "test" (not "prod")
   - VPC CIDR blocks don't overlap with existing networks

2. **Set up billing alerts** in AWS Console:
   - Go to AWS Billing → Budgets
   - Create alert for unexpected charges

3. **Use separate AWS accounts** for testing when possible:
   - Use a dedicated test/dev AWS account
   - Never run integration tests in production accounts

4. **Monitor resource creation**:
   - Check AWS Console during test runs
   - Verify resources are cleaned up after tests

### Estimated Costs (Per Integration Test Run)

- **VPC, Subnets, Security Group**: Free tier eligible
- **S3 Bucket**: ~$0.01 (minimal storage)
- **KMS Key**: ~$1.00/month (pro-rated)
- **EC2 t3.micro Instance**: ~$0.01-0.05 (short-lived)

**Total per run**: ~$1-2 (varies by region and runtime)

### Best Practices

✅ **DO**:
- Run unit/mock/validation/compliance tests regularly (they're FREE)
- Run integration tests before major deployments only
- Verify resources are cleaned up after each test
- Use `terraform test -filter=unit_* -filter=compliance_*` for regular testing

❌ **DON'T**:
- Run integration tests in production AWS accounts
- Leave integration tests running with `-cleanup=false`
- Use production variable values in integration tests
- Run integration tests frequently (costs add up)

### Cleanup Failed Tests

If a test fails and resources aren't cleaned up:

```bash
# Navigate to the test directory
cd tests

# Manually destroy resources (if test state exists)
terraform destroy

# Or use AWS Console to manually delete:
# - VPC and associated resources
# - S3 buckets (must be empty first)
# - KMS keys (scheduled for deletion)
# - EC2 instances
```

## Test Coverage Summary

| Resource Type | Unit Tests | Integration Tests | Validation Tests | Compliance Tests |
|--------------|------------|-------------------|------------------|------------------|
| VPC | ✅ | ✅ | ✅ | ✅ |
| Subnets | ✅ | ✅ | ✅ | ✅ |
| Security Groups | ✅ | ✅ | ✅ | ✅ |
| S3 Bucket | ✅ | ✅ | ❌ | ✅ |
| KMS Key | ✅ | ✅ | ✅ | ✅ |
| EC2 Instance | ✅ | ✅ | ✅ | ✅ |
| Variables | ❌ | ❌ | ✅ (13 validations) | ❌ |
| Outputs | ❌ | ✅ | ❌ | ❌ |

## Continuous Integration

### Recommended CI/CD Pipeline

```yaml
# Example GitHub Actions workflow
test:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v3
    - uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: 1.8.0

    # Safe tests (free, no AWS credentials needed)
    - name: Run unit tests
      run: terraform test -filter=unit_*

    - name: Run mock tests
      run: terraform test -filter=mock_*

    - name: Run validation tests
      run: terraform test -filter=validation_*

    - name: Run compliance tests
      run: terraform test -filter=compliance_*

    # Integration tests (optional, requires AWS credentials)
    - name: Configure AWS Credentials
      if: github.ref == 'refs/heads/main'
      uses: aws-actions/configure-aws-credentials@v2
      with:
        role-to-assume: ${{ secrets.AWS_TEST_ROLE }}
        aws-region: eu-central-1

    - name: Run integration tests
      if: github.ref == 'refs/heads/main'
      run: terraform test -filter=integration_*
```

## Troubleshooting

### Common Issues

**Issue**: `Error: Required variable not set`
- **Solution**: Ensure all required variables are defined in the test's `variables` block

**Issue**: `Error: data source not found`
- **Solution**: Check that `override_data` blocks are present for all data sources in unit/mock tests

**Issue**: `Error: Invalid index` on set-type attributes
- **Solution**: Use `for` expressions instead of `[0]` indexing (see anti-patterns)

**Issue**: Integration test resources not cleaned up
- **Solution**: Check test logs for errors, manually clean up via AWS Console or `terraform destroy`

**Issue**: `Error: precondition failed`
- **Solution**: Verify variable values meet precondition requirements (e.g., t2.micro only in dev)

## Test Development

When adding new tests:

1. **Follow naming conventions**: `{type}_{feature}.tftest.hcl`
2. **Always mock data sources** in unit tests
3. **Use test-specific values** in integration tests
4. **Document expected behavior** in assertions
5. **Test both success and failure paths** (validation tests)

## Additional Resources

- [Terraform Testing Documentation](https://developer.hashicorp.com/terraform/language/tests)
- [Terraform Test Framework](https://developer.hashicorp.com/terraform/tutorials/configuration-language/test)
- See `COVERAGE.md` for detailed test coverage report

## Support

For issues or questions about these tests:
- Check the main project README
- Review anti-pattern documentation in the skill
- Consult Terraform testing best practices
