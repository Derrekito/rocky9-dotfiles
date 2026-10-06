# vendor/

Release files `install.sh` installs, listed in `MANIFEST`: Neovim, the
tree-sitter CLI, and hunk, x86_64 builds. Only `MANIFEST` and this README are
tracked; the files themselves are copied in by hand. `install.sh` never
downloads them.

Fill it from a machine that already has them:

```bash
rsync -av vendor/ vm:rocky9-dotfiles/vendor/
```

Or download them on a machine with internet access, then copy them over:

```bash
provision/fetch-vendor.sh      # downloads each MANIFEST file and checks its sha256
```

`install.sh` stops with an error that names the file if one is missing or its
sha256 doesn't match `MANIFEST`, for example a newer release under the same
file name. To change a version, update its line in `MANIFEST`: version,
sha256 and url.
