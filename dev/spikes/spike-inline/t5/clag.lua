-- clag.lua: resolve governed spans  [arm1 | arm2]{.by}[]{.clag-pick arm=".." text=".."}
local function has(el, cls) return el.t == "Span" and el.classes:includes(cls) end

local function trim(list)
  while #list > 0 and (list[1].t == "Space" or list[1].t == "SoftBreak") do list:remove(1) end
  while #list > 0 and (list[#list].t == "Space" or list[#list].t == "SoftBreak") do list:remove(#list) end
  return list
end

local function resolve(governed, pick)
  local arm = tonumber(pick.attributes["arm"])
  local text = pick.attributes["text"] or ""
  local arms, cur = {pandoc.List()}, 1
  for _, el in ipairs(governed.content) do
    if el.t == "Str" and el.text == "|" then
      cur = cur + 1; arms[cur] = pandoc.List()
    else
      arms[cur]:insert(el)
    end
  end
  local chosen = trim(arms[arm] or pandoc.List())
  local out = pandoc.List()
  for _, el in ipairs(chosen) do
    if el.t == "Str" and el.text == "#" then out:insert(pandoc.Str(text)) else out:insert(el) end
  end
  return out
end

function Inlines(inlines)
  local out, i, changed = pandoc.List(), 1, false
  while i <= #inlines do
    local a, b = inlines[i], inlines[i + 1]
    if has(a, "by") and b and has(b, "clag-pick") then        -- span then marker
      out:extend(resolve(a, b)); i = i + 2; changed = true
    elseif has(a, "clag-pick") and b and has(b, "by") then    -- marker then span (governor-first)
      out:extend(resolve(b, a)); i = i + 2; changed = true
    else
      out:insert(a); i = i + 1
    end
  end
  if changed then return out end
end
