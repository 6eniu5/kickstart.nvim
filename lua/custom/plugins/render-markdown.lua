-- In-buffer markdown rendering: headings, tables, code blocks, checkboxes,
-- callouts and YAML frontmatter are drawn as decorations over the real text.
-- Nothing is written to the buffer, and the raw source reappears on the line
-- the cursor sits on, so editing still works normally.
--
-- Dependencies are all already declared in init.lua: nvim-treesitter (with the
-- `markdown`, `markdown_inline`, `html` and `yaml` parsers) and mini.nvim,
-- which supplies mini.icons as the icon provider. Symbols need a Nerd Font —
-- wezterm is set to JetBrainsMono Nerd Font, installed by esetup.

---@module 'lazy'
---@type LazySpec
return {
  'MeanderingProgrammer/render-markdown.nvim',
  dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.nvim' },
  ft = { 'markdown' },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    -- Render everywhere except insert mode, where the raw source is easier to edit.
    render_modes = { 'n', 'v', 'i', 'c', 't' },
    anti_conceal = { enabled = true },
    heading = { position = 'inline' },
    code = { width = 'block', min_width = 45, right_pad = 2 },
    -- Obsidian vault notes lead with frontmatter; render it rather than hide it.
    win_options = { conceallevel = { rendered = 2 } },
  },
  keys = {
    { '<leader>tm', '<cmd>RenderMarkdown toggle<cr>', desc = '[T]oggle [M]arkdown rendering', ft = 'markdown' },
  },
}
