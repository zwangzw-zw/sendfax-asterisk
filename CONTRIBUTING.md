# Contributing to Asterisk SendFax Script

Thank you for your interest in contributing to this project! We welcome contributions of all kinds, from bug reports and feature requests to code improvements and documentation updates.

## Table of Contents
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contribution Guidelines](#contribution-guidelines)
- [Code Style](#code-style)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting](#issue-reporting)

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/your-username/asterisk-sendfax.git
   cd asterisk-sendfax
   ```
3. Create a new branch for your feature or fix:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Prerequisites
- Bash shell environment
- Asterisk PBX system (for testing)
- Ghostscript (`gs`)
- ImageMagick (`magick`/`convert`)
- Standard Unix tools (`sed`, `awk`, `fold`, `fmt`)

### Test Environment
For development and testing, you can use:
- A local Asterisk installation
- Docker container with Asterisk
- Virtual machine with Asterisk

### Configuration for Testing
Create a test configuration by copying the script and modifying the configuration section:
```bash
cp sendfax.sh sendfax-test.sh
# Edit configuration variables for your test environment
```

## Contribution Guidelines

### Types of Contributions Welcome
- 🐛 **Bug fixes** - Fix issues with existing functionality
- ✨ **New features** - Add new capabilities or options
- 📖 **Documentation** - Improve README, add examples, code comments
- 🎨 **Code improvements** - Refactor, optimize, or clean up code
- 🧪 **Tests** - Add test cases or improve testing coverage
- 🚀 **Performance** - Optimize PostScript generation or text processing

### What We're Looking For
- Improvements to error handling and validation
- Support for additional Asterisk configurations
- Enhanced PostScript/PDF processing
- Better internationalization support
- Additional output formats
- Integration with other fax systems
- Performance optimizations

## Code Style

### Bash Script Standards
- Use 4 spaces for indentation (no tabs)
- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) principles
- Use meaningful variable names with clear prefixes
- Add comments for complex logic sections
- Include function documentation

### Example Code Style
```bash
# Good: Clear function with documentation
generate_coversheet() {
    local recipient_number="$1"
    local recipient_name="$2"
    local subject="$3"
    local message="$4"
    local priority="$5"
    
    # Process recipient name if provided
    if [[ "$recipient_name" == *"<"*">" ]]; then
        # Extract name from "Name <phone>" format
        recipient_display=$(echo "$recipient_name" | sed 's/<[^>]*>//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    else
        recipient_display="$recipient_number"
    fi
    
    # Generate PostScript content
    cat > "$COVERSHEET_FILE" << EOF
    %!PS-Adobe-3.0
    % Coversheet generation logic here
EOF
}
```

### Variable Naming Conventions
- `ALL_CAPS` for configuration constants
- `snake_case` for local variables
- `TEMP_FILE` patterns for temporary files
- Clear prefixes for related variables (`FAX_`, `COVER_`, etc.)

## Testing

### Manual Testing Checklist
Before submitting a pull request, please test:

1. **Basic functionality**:
   - [ ] Simple phone number transmission
   - [ ] Named recipient format
   - [ ] With and without coversheet
   - [ ] Different priority levels

2. **Edge cases**:
   - [ ] Very long messages (>18 lines)
   - [ ] Special characters in names
   - [ ] International phone formats
   - [ ] Empty/minimal parameters

3. **Error conditions**:
   - [ ] Invalid phone numbers
   - [ ] Missing PDF files
   - [ ] Invalid priority levels
   - [ ] Insufficient permissions

### Test Script Example
Create comprehensive test cases:
```bash
#!/bin/bash
# test-sendfax.sh - Basic test suite

echo "Testing basic transmission..."
./sendfax.sh 5551234567 test.pdf "Test" "Basic test message"

echo "Testing named recipient..."
./sendfax.sh "John Doe <5551234567>" test.pdf "Test" "Named recipient test"

echo "Testing without coversheet..."
./sendfax.sh --nocover 5551234567 test.pdf

# Add more test cases as needed
```

## Pull Request Process

1. **Prepare your changes**:
   - Write clear, descriptive commit messages
   - Keep commits focused on single changes
   - Update documentation as needed

2. **Test thoroughly**:
   - Test all affected functionality
   - Verify no regressions introduced
   - Test edge cases and error conditions

3. **Submit pull request**:
   - Provide clear title and description
   - Reference any related issues
   - Include testing details

### Pull Request Template
```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Basic functionality tested
- [ ] Edge cases tested
- [ ] No regressions introduced

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated (if needed)
- [ ] Changes tested in realistic environment
```

## Issue Reporting

### Bug Reports
When reporting bugs, please include:
- Operating system and version
- Asterisk version
- Script configuration (sanitized)
- Complete error messages
- Steps to reproduce
- Expected vs. actual behavior

### Feature Requests
For feature requests, please describe:
- Use case and motivation
- Proposed solution or approach
- Alternative solutions considered
- Additional context

### Issue Labels
We use these labels to categorize issues:
- `bug` - Something isn't working
- `enhancement` - New feature or request
- `documentation` - Documentation improvements
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention is needed

## Code Review Process

### What Reviewers Look For
- Code correctness and logic
- Adherence to style guidelines  
- Proper error handling
- Clear documentation
- Test coverage
- Performance implications
- Security considerations

### Response to Feedback
- Address all reviewer comments
- Ask questions if feedback is unclear
- Make requested changes promptly
- Explain reasoning for any disagreements

## Development Tips

### Debugging PostScript
```bash
# Generate PostScript without conversion for inspection
gs -dNOPAUSE -dBATCH -sDEVICE=ps2write -sOutputFile=debug.ps input.pdf

# Test PostScript syntax
gs -dNOPAUSE -dBATCH -sDEVICE=nullpage coversheet.ps
```

### Testing with Different Asterisk Versions
- Test with common Asterisk versions (16, 18, 20)
- Verify SIP/PJSIP compatibility
- Check fax module functionality

### Performance Optimization
- Profile PostScript generation time
- Optimize text processing loops
- Minimize external tool calls
- Cache reusable calculations

## Community Guidelines

### Be Respectful
- Use welcoming and inclusive language
- Be respectful of differing viewpoints
- Give constructive feedback
- Focus on what is best for the community

### Communication Channels
- **GitHub Issues** - Bug reports and feature requests
- **Pull Requests** - Code review and discussion
- **Discussions** - General questions and ideas

## Recognition

Contributors will be recognized in:
- CONTRIBUTORS.md file
- Release notes for significant contributions
- GitHub contributor statistics

Thank you for contributing to make this project better! 🎉