# vendor/

What `install.sh` installs instead of downloading. Only `MANIFEST` and this
README are tracked; everything else is copied in by hand.

- **Release files** listed in `MANIFEST`: Neovim, the tree-sitter CLI and hunk,
  as x86_64 builds.
- **`nvim-plugins/<name>/`**: every Neovim plugin in `nvim/plugins.lock`, as
  plain files at the pinned commit (submodules included, no git history). Each
  has a `nvim-plugins/<name>.commit` naming that commit.
  `nvim/install-plugins.sh` refuses a plugin whose commit isn't the one
  `plugins.lock` pins. Your own plugins (Derrekito/*) use a local checkout
  under `~/devel` or `~/Projects` instead, when there is one.

Fill it from a machine that already has them:

```bash
rsync -av vendor/ vm:rocky9-dotfiles/vendor/
```

Or download them on a machine with internet access, then copy them over:

```bash
provision/fetch-vendor.sh   # MANIFEST files (sha256-checked) + every plugin at its pin
```

It keeps the plugins' git clones in `~/.cache/rocky9-dotfiles/plugin-src`, so
re-running after a pin changes only fetches that plugin.

`install.sh` stops with an error that names the file if one is missing or its
sha256 doesn't match `MANIFEST`, for example a newer release under the same
file name. It does the same for a plugin that's missing or at a different
commit than `plugins.lock`. To change a version, update its line in `MANIFEST`
(version, sha256 and url) or its commit in `nvim/plugins.lock`, then re-run
`fetch-vendor.sh` and copy `vendor/` over. `./doctor.sh` lists anything
missing or stale.
