function Span(el)
  if el.attributes["n"] then
    local f = io.open("filter-hits.txt", "a"); f:write((PANDOC_STATE.input_files[1] or "?") .. ": span n=" .. el.attributes["n"] .. " text=" .. pandoc.utils.stringify(el) .. "\n"); f:close()
  end
end
function Code(el)
  if el.text:match("^r ") then
    local f = io.open("filter-hits.txt", "a"); f:write((PANDOC_STATE.input_files[1] or "?") .. ": unevaluated inline code " .. el.text .. "\n"); f:close()
  end
end
