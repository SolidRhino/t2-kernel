# CLAUDE.md

Strictly follow the rules and context in [AGENTS.md](./AGENTS.md).

## Additional Claude-Specific Guidelines

### Development Workflow

When working on this repository:

1. **Always read AGENTS.md first** for full context
2. **Check workflow logs** before making changes to GitHub Actions
3. **Test locally** with `nix flake check` and `nix build` before committing
4. **Follow commit conventions** described in AGENTS.md
5. **Be mindful of CI budget** - we use ~1,320 of 2,000 free minutes/month

### Branch Naming for Claude Sessions

Use the format: `claude/<task>-<session-id>`

Example: `claude/add-experimental-kernel-01234abcd`

### Key Reminders

- **Never manually edit flake.lock** - Let `nix flake update` handle it
- **Test workflows locally first** - Saves CI minutes
- **Check nixos-hardware docs** before modifying kernel definitions
- **Verify Cachix secrets** are set before pushing workflow changes
- **Review AGENTS.md** for complete technical details

### When Making Changes

**To workflows:**
1. Read current workflow in `.github/workflows/`
2. Test logic locally if possible
3. Consider CI minute impact
4. Update AGENTS.md if adding new features

**To flake.nix:**
1. Validate with `nix flake check`
2. Test build with `nix build .#<package>`
3. Verify kernel versions with `nix eval`
4. Consider impact on both stable and latest variants

**To documentation:**
1. Keep README.md user-focused
2. Keep AGENTS.md technical/implementation-focused
3. Update both if adding features

---

For complete technical documentation, build instructions, testing procedures, and troubleshooting, see **[AGENTS.md](./AGENTS.md)**.
