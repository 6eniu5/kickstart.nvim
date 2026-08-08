-- Routed link opening. The logic lives in `custom.links`; this file exists only
-- because `lua/custom/plugins/` is what kickstart imports, and it is the
-- merge-safe place to add to.
--
-- No plugin is being declared, hence the empty spec. `setup()` guards itself
-- against running twice, so a re-import cannot wrap `vim.ui.open` in a second
-- copy of itself.
require('custom.links').setup()

---@module 'lazy'
---@type LazySpec
return {}
