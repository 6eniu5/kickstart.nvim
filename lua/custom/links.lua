--[[ Links, opened in the browser identity the FILE belongs to.

Two entry points, one decision underneath:

  gx            the built-in, which dispatches through `vim.ui.open` — so
                overriding that routes it, and routes every plugin that opens a
                URL along with it.
  <leader>su    every link in the buffer, through `vim.ui.select`.

The directory that decides is the one the BUFFER'S FILE lives in, not Neovim's
working directory. You open the editor at a project root, or at $HOME, and read a
file that lives inside a work folder; it is the file's location that says whose
link this is. `identity browser open --from` exists for exactly this caller.

Routing needs the private `identity` repo. Absent — which is every machine but
one, since it is private — every path here falls back to stock behaviour and the
link still opens, unrouted.
]]

local M = {}

-- Only these reach a browser. A markdown link to another file is a link to
-- another FILE: sending `./design.md` to Chrome renders raw markdown, which is
-- never what was wanted, so those open in Neovim instead. See M.open.
local ROUTED = { ['http'] = true, ['https'] = true, ['mailto'] = true }

function M.is_routed(target)
  local scheme = tostring(target):match('^(%a[%w+.-]*):')
  return scheme ~= nil and ROUTED[scheme:lower()] == true
end

-- A URL at the end of a sentence collects the full stop; one inside prose
-- collects the closing paren. Neither belongs to the link. The cost is a genuine
-- trailing paren in a URL, which is rare and visible in the picker first.
local function trim_trailing(s)
  return (s:gsub('[%.,;:!%?%)%]}\'"]+$', ''))
end

-- Every match of one pattern, with the position it was found at, so results from
-- several patterns can be merged back into document order rather than grouped by
-- which pattern happened to find them.
local function scan(text, pattern)
  local found, init = {}, 1
  while true do
    local s, e, capture = text:find(pattern, init)
    if not s then break end
    found[#found + 1] = { pos = s, value = capture }
    init = e > s and e + 1 or s + 1
  end
  return found
end

--- Candidate links in `text`, in document order, deduped.
---
--- Markdown link TARGETS count, not the text they wrap: in `[the spec](./a.md)`
--- the link is `./a.md`. Bare URLs count too, which is most of what a plain file
--- or a code comment contains.
---@param text string
---@return string[]
function M.extract(text)
  local hits = {}
  vim.list_extend(hits, scan(text, '%]%(([^%)%s]+)%)'))
  vim.list_extend(hits, scan(text, '(%a[%w+.-]*://[^%s%)%]<>"\'`]+)'))
  vim.list_extend(hits, scan(text, '(mailto:[^%s%)%]<>"\'`]+)'))
  table.sort(hits, function(a, b) return a.pos < b.pos end)

  local out, seen = {}, {}
  for _, hit in ipairs(hits) do
    local value = trim_trailing(hit.value)
    if value ~= '' and not seen[value] then
      seen[value] = true
      out[#out + 1] = value
    end
  end
  return out
end

--- The directory whose identity should answer for the current buffer.
--- Falls back to Neovim's cwd for a buffer that has no file yet.
---@return string
function M.buffer_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if name == nil or name == '' then return vim.uv.cwd() end
  return vim.fs.dirname(vim.fn.fnamemodify(name, ':p'))
end

local stock_open = nil

--- Open one target the right way. Returns what `vim.ui.open` promises, because
--- the built-in `gx` calls `cmd:wait(1000)` on the first return value and reads
--- `rv.code` off it — a bare `nil` is tolerated by its guard, anything else
--- shaped differently is not.
---@return vim.SystemObj|nil, string|nil
function M.open(target, opt)
  if not M.is_routed(target) then
    -- A file path next to the document usually means "the note this one links
    -- to", so open it here rather than handing it to the system.
    local candidate = vim.fs.normalize(target)
    if not candidate:match('^/') then
      candidate = vim.fs.joinpath(M.buffer_dir(), candidate)
    end
    if vim.fn.filereadable(candidate) == 1 then
      vim.cmd.edit(vim.fn.fnameescape(candidate))
      return nil, nil
    end
    return stock_open(target, opt)
  end

  if vim.fn.executable('identity') == 0 then return stock_open(target, opt) end
  return vim.system({ 'identity', 'browser', 'open', '--from', M.buffer_dir(), target }), nil
end

--- Pick from every link in the buffer. `vim.ui.select` is already rendered by
--- telescope-ui-select here, so this needs no picker of its own.
function M.pick()
  local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  local links = M.extract(text)
  if #links == 0 then
    vim.notify('no links in this buffer', vim.log.levels.INFO)
    return
  end
  vim.ui.select(links, { prompt = 'Open link:' }, function(choice)
    if choice then M.open(choice) end
  end)
end

function M.setup()
  -- Captured once. Wrapping an already-wrapped function — which is what a second
  -- setup() would do — builds a chain that calls identity twice for one link.
  if stock_open ~= nil then return end
  stock_open = vim.ui.open
  vim.ui.open = M.open
  vim.keymap.set('n', '<leader>su', M.pick, { desc = '[S]earch [U]RLs in buffer' })
end

return M
