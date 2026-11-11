-- clag-check.lua: fail the render if any clag construct survived knitting (i.e. the hooks were not active).
local bad = {}
local function add(kind, text) bad[#bad + 1] = kind .. ": " .. text end

local function has_clag_attr(attr)
  for _, k in ipairs({ "n", "if", "claim" }) do
    if attr.attributes[k] ~= nil then return k end
  end
end

local function Span(el)
  local k = has_clag_attr(el)
  if k then add("span with attribute '" .. k .. "'", "[" .. pandoc.utils.stringify(el.content) .. "]{" .. k .. "=\"" .. el.attributes[k] .. "\"}") end
end

-- leftover value attribute block, e.g.  1.2{.num}   or   {claim="..."} (pandoc keeps these as plain Str)
local function Str(el)
  local t = el.text
  if t:find("%{%s*%.[%a][%w_-]*") or t:find("%{%s*claim%s*=") or t:find("%{%s*n%s*=") or t:find("%{%s*if%s*=") then
    add("unprocessed attribute block", t)
  end
end

local function Pandoc(doc)
  if #bad > 0 then
    error("clag-check: " .. #bad .. " clag construct(s) survived knitting; the clag hooks were not active.\n  "
          .. table.concat(bad, "\n  "))
  end
end

return { { Span = Span, Str = Str }, { Pandoc = Pandoc } }
