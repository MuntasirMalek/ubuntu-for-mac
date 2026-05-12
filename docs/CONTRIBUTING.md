# Contributing to Ubuntu Mac Builder

Thanks for wanting to help! This project aims to make Linux on Macs painless for everyone.

## How to Contribute

### 1. Test on Your Hardware

The most valuable contribution is testing on Mac hardware we haven't verified yet.

**What to report:**
- Your Mac model (run `system_profiler SPHardwareDataType` on macOS)
- Ubuntu version used
- What works / what doesn't
- Any fixes you applied

Open an issue with the **"Hardware Report"** template.

### 2. Fix a Bug

1. Fork the repo
2. Create a branch: `git checkout -b fix/your-fix-name`
3. Make your changes
4. Test if possible
5. Submit a PR

### 3. Add Support for a New Model

If you got Linux working on a Mac model not listed in our supported models:

1. Document what packages/configs were needed
2. Add your model to `docs/SUPPORTED-MODELS.md`
3. If new packages are needed, add them to the appropriate list in `config/packages/`
4. If new configs are needed, add them to `config/modprobe/` or `config/udev/`
5. Submit a PR

### 4. Improve Documentation

Documentation improvements are always welcome, especially:
- Clearer installation steps
- Screenshots of the process
- Translations

## Code Style

- Shell scripts: Use `shellcheck` and follow Google's shell style guide
- Keep scripts POSIX-compatible where possible
- Comment complex logic
- Test on both Ubuntu and the Docker build environment

## Reporting Issues

When reporting issues, please include:
- Mac model and year
- Ubuntu version
- Output of `lspci -nnk | grep -iA3 network` (for WiFi issues)
- Output of `dmesg | tail -50` (for driver issues)
- Output of `dkms status` (for DKMS issues)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
