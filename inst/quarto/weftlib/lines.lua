-- weftlib/lines.lua: the line of a construct, by text search in the source (dev/design-6.md N89, D21).
--
--   local lines = dofile("weftlib/lines.lua")
--   local L = lines.new(path)          -- nil when the file cannot be read
--   file, line = L:find(needle, ok)    -- the next occurrence after the previous one of the same
--                                      -- needle; ok(text, start) may reject a match; nil if none
--
-- The searchable text is the source with each `{{< include F >}}` line replaced by F's searchable
-- text (relative to the including file, recursively, at most 8 deep), with fenced code blocks
-- blanked except their lines that start `#|`, and HTML comments blanked, line structure kept.
-- No side effect on load.

local M = {}
M.__index = M

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("a")
  f:close()
  return s
end

local function dir_of(path)
  local d = path:gsub("[/\\]+[^/\\]*$", "")
  if d == path then return "." end
  return d
end

local function join(dir, rel)
  if rel:sub(1, 1) == "/" or rel:match("^%a:[/\\]") then return rel end
  local p = dir .. "/" .. rel
  p = p:gsub("/%./", "/"):gsub("^%./", "")
  return p
end

-- the lines of a text with fenced code and comments blanked
local function masked_lines(text)
  text = text:gsub("<!%-%-.-%-%->", function(m) return (m:gsub("[^\n]", "")) end)
  local out, n = {}, 0
  local fence_char, fence_len
  for line in (text .. "\n"):gmatch("(.-)\r?\n") do
    n = n + 1
    local keep = line
    local marks = line:match("^[ \t\r\n>]*(`+)") or line:match("^[ \t\r\n>]*(~+)")
    if fence_char then
      local close = line:match("^[ \t\r\n>]*(" .. fence_char .. "+)[ \t\r\n]*$")
      if close and #close >= fence_len then fence_char = nil
      elseif not line:match("^[ \t\r\n]*#|") then keep = "" end
      if fence_char == nil then keep = "" end
    elseif marks and #marks >= 3 then
      fence_char = marks:sub(1, 1)
      if fence_char == "`" then fence_char = "`" else fence_char = "~" end
      fence_len = #marks
      keep = ""
    end
    out[n] = keep
  end
  -- a trailing empty line is an artefact of the final newline
  if n > 0 and out[n] == "" and text:sub(-1) == "\n" then out[n] = nil end
  return out
end

local function expand(path, depth, parts, files, seen_files)
  local text = read_file(path)
  if not text then return false end
  local idx = #files + 1
  files[idx] = path
  local masked = masked_lines(text)
  for i = 1, #masked do
    local line = masked[i]
    local inc = line:match("^[ \t\r\n]*{{<[ \t\r\n]*include[ \t\r\n]+([^ \t\r\n]+)[ \t\r\n]*>}}[ \t\r\n]*$")
    local done = false
    if inc and depth < 8 then
      local target = join(dir_of(path), inc)
      done = expand(target, depth + 1, parts, files, seen_files)
    end
    if not done then parts[#parts + 1] = { idx, i, line } end
  end
  return true
end

function M.new(path)
  if not path then return nil end
  local parts, files = {}, {}
  if not expand(path, 0, parts, files) then return nil end
  local buf, starts, pos = {}, {}, 1
  for i, p in ipairs(parts) do
    starts[i] = pos
    buf[i] = p[3]
    pos = pos + #p[3] + 1
  end
  return setmetatable({
    text = table.concat(buf, "\n"), starts = starts, parts = parts, files = files, cursor = {},
  }, M)
end

function M:locate(pos)
  local lo, hi = 1, #self.starts
  if hi == 0 then return nil end
  while lo < hi do
    local mid = (lo + hi + 1) // 2
    if self.starts[mid] <= pos then lo = mid else hi = mid - 1 end
  end
  local p = self.parts[lo]
  return p[1], p[2]
end

-- the next match of one needle: its start and end, or nil; nothing is committed
function M:next_match(needle, ok)
  local from = self.cursor[needle] or 1
  while true do
    local s, e = self.text:find(needle, from, true)
    if not s then return nil end
    if not ok or ok(self.text, s) then return s, e end
    from = s + 1
  end
end

-- the file index (into self.files) and line of the next occurrence of needle. A needle holding `|` is
-- also searched in its escaped form `\|`, which a pipe table needs (the tree holds the unescaped
-- text): the earlier of the two matches wins.
function M:find(needle, ok)
  local s, e = self:next_match(needle, ok)
  local used = needle
  if needle:find("|", 1, true) then
    local esc = needle:gsub("|", "\\|")
    local s2, e2 = self:next_match(esc, ok)
    if s2 and (not s or s2 < s) then s, e, used = s2, e2, esc end
  end
  if not s then return nil end
  self.cursor[used] = e + 1
  return self:locate(s)
end

return M
