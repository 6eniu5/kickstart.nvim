-- Tests for custom.links — extraction and the routed/not-routed decision.
--
--   nvim -l test-links.lua      exit 0 = pass
--
-- Pure functions only: no buffer, no browser, no `identity` on PATH. Run with
-- `-l`, which loads no plugins, so this says the same thing on a machine where
-- lazy has never installed anything.

-- Loaded by explicit path, NOT by `require`. Neovim's loader searches the
-- runtimepath first, so `require('custom.links')` finds the INSTALLED module and
-- ignores whatever sits beside this file — which makes the suite silently test
-- something other than what it was pointed at. Caught by mutation: two deliberate
-- bugs in a copy of the module passed every case, because no copy was ever read.
local here = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h')
local links = dofile(here .. '/lua/custom/links.lua')

local pass, fail = 0, 0

local function check(what, got, want)
  local same = #got == #want
  if same then
    for i = 1, #want do
      if got[i] ~= want[i] then same = false break end
    end
  end
  if same then
    pass = pass + 1
  else
    fail = fail + 1
    io.write(('  FAIL  %s\n        want: %s\n        got:  %s\n')
      :format(what, table.concat(want, ' | '), table.concat(got, ' | ')))
  end
end

local function extract(what, text, want) check(what, links.extract(text), want) end

-- --- extraction ------------------------------------------------------------

extract('a bare url is found',
  'see https://example.com/a for details',
  { 'https://example.com/a' })

-- A markdown link contributes its TARGET, never the text wrapping it: in
-- `[the spec](./a.md)` the link is the file, not the words.
extract('a markdown link contributes its target, not its text',
  'read [the spec](https://example.com/spec) first',
  { 'https://example.com/spec' })

extract('a relative markdown target is a candidate too',
  'see [the design](./design.md) for why',
  { './design.md' })

-- Document order, across both kinds. This is what the position-sorted merge is
-- for: collecting markdown targets and bare URLs separately and concatenating
-- would group them by pattern instead.
extract('markdown and bare links interleave in document order',
  'first [a](./a.md) then https://b.example/2 then [c](./c.md)',
  { './a.md', 'https://b.example/2', './c.md' })

extract('a repeated link appears once, at its first position',
  'https://x.example/1 and later https://x.example/1 again',
  { 'https://x.example/1' })

extract('a trailing full stop is not part of the url',
  'go to https://example.com/page.',
  { 'https://example.com/page' })

extract('a url inside prose parentheses loses the closing paren',
  'the docs (see https://example.com/docs) explain it',
  { 'https://example.com/docs' })

extract('mailto counts',
  'write to mailto:someone@example.com about it',
  { 'mailto:someone@example.com' })

extract('a bare word with a dot is not a link',
  'example.com is not a link without a scheme',
  {})

extract('nothing in, nothing out', '', {})

extract('query strings and fragments survive',
  'https://example.com/s?q=a+b&n=2#frag',
  { 'https://example.com/s?q=a+b&n=2#frag' })

-- --- the routed / not-routed decision --------------------------------------

local function routed(what, target, want)
  local got = links.is_routed(target)
  if got == want then
    pass = pass + 1
  else
    fail = fail + 1
    io.write(('  FAIL  %s\n        want: %s\n        got:  %s\n')
      :format(what, tostring(want), tostring(got)))
  end
end

routed('https goes to the browser', 'https://example.com', true)
routed('http goes to the browser', 'http://example.com', true)
routed('mailto goes to the browser', 'mailto:a@example.com', true)
routed('scheme matching is case-insensitive', 'HTTPS://example.com', true)

-- These are the whole point of the distinction: a markdown link to another note
-- must not be handed to Chrome, which would render raw markdown.
routed('a relative file path is not routed', './design.md', false)
routed('an absolute file path is not routed', '/tmp/notes.md', false)
routed('a file:// url is not routed', 'file:///tmp/notes.md', false)
routed('an ssh remote is not routed', 'git@github.com:kernvex/dotfiles.git', false)

io.write(('\n%d passed, %d failed\n'):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
