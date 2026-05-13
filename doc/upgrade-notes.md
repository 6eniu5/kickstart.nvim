# Post-upgrade checklist

Run these after a Neovim version bump (e.g. `brew upgrade neovim`).

## 1. Clear the lua bytecode cache

Neovim caches compiled lua modules under `~/.cache/nvim/luac/`, keyed by the **absolute source path** — which on Homebrew includes the version (`/opt/homebrew/Cellar/neovim/<version>/...`). After an upgrade those paths no longer exist, the cache loader finds stale entries first, and `require(...)` fails for runtime modules.

Symptom: errors like

```
module 'editorconfig' not found
  cache_loader: module 'editorconfig' not found
  cache_loader_lib: module 'editorconfig' not found
```

with a stack trace pointing at a Cellar path for the **old** version.

Fix:

```sh
rm -rf ~/.cache/nvim/luac
```

The cache regenerates automatically on next launch.

## 2. Update plugins

```
:Lazy sync
```

Plugins compiled against the old runtime (especially treesitter parsers and anything with native components) may need rebuilding.

## 3. Rebuild treesitter parsers

```
:TSUpdate
```

Required when the bundled treesitter library version changes between Neovim releases.

## 4. Check health

```
:checkhealth
```

Surfaces any provider, LSP, or plugin breakage from the upgrade.

## 5. Restart any running nvim sessions

A running nvim process keeps the **old** binary's runtime files mapped. Quit and relaunch — don't rely on `:source $MYVIMRC`.
