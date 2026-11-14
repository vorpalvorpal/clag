# The setting `chunk_claims`, read by the guest at a failed claim (GN4 of dev/design-8.md). The same
# reading as weft/_config.py: the files are read at each call and nothing is kept. Base only.
#
#   _weft.yml  the first one found in the folder or up to 8 parents: the first line that starts at
#              column 1 with `chunk_claims`, optional spaces or tabs, then `:`. The value is the rest
#              of the line, a `#` comment that follows white space removed, trimmed, one pair of
#              surrounding quotes removed.
#   document   when the source ends .qmd or .md: the key `chunk_claims` of the `weft:` mapping of its
#              front matter, in block or flow form. The document's value, when it has one, wins.
#
# The result is "collect" exactly when the value that applies is `collect`, else "stop".

const _CC_KEY = r"^chunk_claims[ \t]*:(.*)$"
const _CC_COMMENT = r"(?:^|\s)#"

function _cc_lines(path::AbstractString)
    raw = try
        read(path, String)
    catch
        return nothing
    end
    startswith(raw, Char(0xFEFF)) && (raw = raw[nextind(raw, 1):end])
    split(replace(replace(raw, "\r\n" => "\n"), '\r' => '\n'), '\n')
end

function _cc_strip_comment(s::AbstractString)
    m = match(_CC_COMMENT, s)
    m === nothing ? String(s) : String(s[1:prevind(s, m.offset)])
end

function _cc_clean(rest::AbstractString)
    s = strip(_cc_strip_comment(rest), [' ', '\t'])
    if length(s) >= 2 && first(s) == last(s) && first(s) in ('"', '\'')
        s = s[nextind(s, 1):prevind(s, lastindex(s))]
    end
    String(s)
end

function _cc_yml_value(folder::AbstractString)
    d = abspath(isempty(folder) ? pwd() : folder)
    for _ in 1:9
        f = joinpath(d, "_weft.yml")
        if isfile(f)
            lines = _cc_lines(f)
            lines === nothing && return nothing
            for line in lines
                m = match(_CC_KEY, line)
                m === nothing || return _cc_clean(m.captures[1])
            end
            return nothing
        end
        up = dirname(d)
        up == d && break
        d = up
    end
    nothing
end

# the first colon outside quotes: (key, rest) or nothing
function _cc_partition_colon(item::AbstractString)
    quote_ = nothing
    for (i, ch) in pairs(item)
        if quote_ !== nothing
            ch == quote_ && (quote_ = nothing)
        elseif ch == '"' || ch == '\''
            quote_ = ch
        elseif ch == ':'
            return (item[1:prevind(item, i)], item[nextind(item, i):end])
        end
    end
    nothing
end

# whether the braces of a flow mapping, seen so far, are closed
function _cc_balanced(text::AbstractString)
    depth = 0
    seen = false
    quote_ = nothing
    for ch in text
        if quote_ !== nothing
            ch == quote_ && (quote_ = nothing)
        elseif ch == '"' || ch == '\''
            quote_ = ch
        elseif ch == '{' || ch == '['
            depth += 1
            seen = true
        elseif ch == '}' || ch == ']'
            depth -= 1
        end
    end
    seen && depth <= 0
end

# the top-level `key: value` items of a flow mapping, as (key, rest) pairs
function _cc_split_flow(text::AbstractString)
    items = String[]
    depth = 0
    quote_ = nothing
    cur = IOBuffer()
    for ch in text
        if quote_ !== nothing
            write(cur, ch)
            ch == quote_ && (quote_ = nothing)
        elseif ch == '"' || ch == '\''
            quote_ = ch
            write(cur, ch)
        elseif ch == '{' || ch == '['
            depth += 1
            depth > 1 && write(cur, ch)
        elseif ch == '}' || ch == ']'
            depth -= 1
            depth >= 1 && write(cur, ch)
            depth <= 0 && break
        elseif ch == ',' && depth == 1
            push!(items, String(take!(cur)))
        else
            write(cur, ch)
        end
    end
    push!(items, String(take!(cur)))
    out = Tuple{String, String}[]
    for it in items
        kv = _cc_partition_colon(it)
        kv === nothing || push!(out, (String(kv[1]), String(kv[2])))
    end
    out
end

function _cc_front_value(source::AbstractString)
    lines = _cc_lines(source)
    (lines === nothing || isempty(lines) || rstrip(lines[1], [' ', '\t']) != "---") && return nothing
    stop = nothing
    for i in 2:length(lines)
        if rstrip(lines[i], [' ', '\t']) in ("---", "...")
            stop = i
            break
        end
    end
    stop === nothing && return nothing
    front = lines[2:stop - 1]
    for (i, line) in enumerate(front)
        m = match(r"^weft[ \t]*:(.*)$", line)
        m === nothing && continue
        rest = strip(_cc_strip_comment(m.captures[1]), [' ', '\t'])
        if startswith(rest, "{")
            text = String(rest)
            j = i + 1
            while !_cc_balanced(text) && j <= length(front)
                text *= " " * strip(_cc_strip_comment(front[j]), [' ', '\t'])
                j += 1
            end
            for (k, v) in _cc_split_flow(text)
                _cc_clean(k) == "chunk_claims" && return _cc_clean(v)
            end
            return nothing
        end
        indent = nothing
        for line2 in front[i + 1:end]
            isempty(strip(line2, [' ', '\t'])) && continue
            ind = length(line2) - length(lstrip(line2, [' ', '\t']))
            ind == 0 && break
            indent === nothing && (indent = ind)
            if ind == indent
                m2 = match(_CC_KEY, line2[ind + 1:end])
                m2 === nothing || return _cc_clean(m2.captures[1])
            end
        end
        return nothing
    end
    nothing
end

"""
    chunk_claims_setting(source, folder) -> "collect" | "stop"

The setting `chunk_claims` for the document `source` (a path, or "") in `folder`: `collect` exactly when the
value that applies, the document's front matter first, then the nearest `_weft.yml`, is `collect`.
"""
function chunk_claims_setting(source::AbstractString, folder::AbstractString)::String
    try
        v = nothing
        if any(e -> endswith(lowercase(source), e), (".qmd", ".md"))
            v = _cc_front_value(source)
        end
        v === nothing && (v = _cc_yml_value(folder))
        v == "collect" ? "collect" : "stop"
    catch
        "stop"
    end
end
