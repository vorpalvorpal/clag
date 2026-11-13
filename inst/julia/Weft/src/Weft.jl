# weft for Julia: @claim (rules N55 to N57 of dev/design-6.md) and put (N70, the
# "Julia put" paragraph of section 4).
#
#     using Weft
#     @claim n > 10
#     @claim mean(d) (_ > 0.5) (_ < 9)
#     Weft.put(depth = 3.2)            # or Weft.put(:depth => 3.2), or @put depth
#
# There are three back ends, chosen at each call (kind()): knitr (R marked it),
# the julia engine (a QuartoNotebookRunner worker: Main.QuartoNotebookWorker
# exists), and none. On the engine a published block is displayed as a Values,
# which has a text/markdown show method, so that Quarto passes it to Pandoc
# (measured 2); with no back end the block's text is printed.
#
# Under a weft knit (JuliaCall in an R knit) R puts this package's folder on
# LOAD_PATH, so `using Weft` loads this copy with nothing to install, and
# calls use_knitr(). A failed check is then noted in CLAIMS; R drains the notes
# after the chunk (drain_claims()) and adds each to the knit's failures or
# warned checks. No RCall call is made.
module Weft

include("record.jl")

export @claim, @put

# ---- exceptions (N3) --------------------------------------------------------------

"A claim at level :fail had a failed check."
struct ClaimFailed <: Exception
    msg::String
end
Base.showerror(io::IO, e::ClaimFailed) = print(io, e.msg)

"A value that cannot be published by name."
struct PublishError <: Exception
    msg::String
end
Base.showerror(io::IO, e::PublishError) = print(io, e.msg)

# ---- the back end -----------------------------------------------------------------

const BACKEND = Ref(:none)          # :none means "look" (kind()); :knitr is set by R
const CLAIMS = Tuple{String, String, String}[]
const PUTS = Pair{String, String}[]  # published records (name => JSON) waiting for R (knitr)

"The back end now: :knitr, :engine (a julia-engine notebook worker) or :none."
function kind()
    BACKEND[] === :none || return BACKEND[]
    isdefined(Main, :QuartoNotebookWorker) ? :engine : :none
end

"Record failed and warned checks for R to drain (the knitr back end, N56)."
function use_knitr()
    BACKEND[] = :knitr
    nothing
end

function __init__()
    # a knit that began before this package was loaded: R marked it
    try
        if isdefined(Main, :WeftGuest) && isdefined(Main.WeftGuest, :KNITR) && Main.WeftGuest.KNITR[]
            BACKEND[] = :knitr
        end
    catch
    end
end

"The notes of failed and warned checks since the last call, as JSON text; cleared."
function drain_claims()::String
    io = IOBuffer()
    print(io, '[')
    for (i, (level, expr, detail)) in enumerate(CLAIMS)
        i > 1 && print(io, ',')
        print(io, '[')
        jstr(io, level); print(io, ',')
        jstr(io, expr); print(io, ',')
        jstr(io, detail)
        print(io, ']')
    end
    print(io, ']')
    empty!(CLAIMS)
    String(take!(io))
end

"The records published since the last call, as JSON text {name: record}; cleared (knitr)."
function drain_puts()::String
    io = IOBuffer()
    print(io, '{')
    for (i, (name, text)) in enumerate(PUTS)
        i > 1 && print(io, ',')
        jstr(io, name); print(io, ':'); print(io, text)
    end
    print(io, '}')
    empty!(PUTS)
    String(take!(io))
end

# ---- the carrier (N20 to N22, N48) -------------------------------------------------

"A block of the carrier, ready to be displayed or printed: its text is the fenced block."
struct Values
    text::String
end
Base.show(io::IO, ::MIME"text/markdown", v::Values) = print(io, v.text)
Base.show(io::IO, ::MIME"text/plain", v::Values) = print(io, v.text)

const RESERVED = ("TRUE", "FALSE", "True", "False", "true", "false", "NA", "NULL", "None",
                  "nothing", "missing", "Inf", "NaN")

"True for a NAME (N6)."
function is_name(s::AbstractString)
    occursin(r"^[A-Za-z_][A-Za-z0-9_.]{0,63}$", s) && !endswith(s, ".") && !(s in RESERVED)
end

const MAX_LIST = 10000

# a record on the wire: no empty members, no host type (as the Python side's wire())
function wire(io::IO, r::Rec)
    print(io, "{\"t\":"); jstr(io, r.t)
    if r.t == "list"
        print(io, ",\"v\":[")
        for (i, el) in enumerate(r.v)
            i > 1 && print(io, ',')
            wire(io, el)
        end
        print(io, "],\"of\":"); jopt(io, r.of)
        print(io, ",\"keys\":")
        if r.keys === nothing
            print(io, "null")
        else
            print(io, '[')
            for (i, k) in enumerate(r.keys)
                i > 1 && print(io, ',')
                jstr(io, k)
            end
            print(io, ']')
        end
    elseif r.t == "missing" || r.t == "error"
        print(io, ",\"why\":"); jopt(io, r.why)
    elseif r.v isa Bool
        print(io, ",\"v\":", r.v ? "true" : "false")
    else
        print(io, ",\"v\":"); jstr(io, r.v)
    end
    print(io, '}')
end

function wire_text(r::Rec)
    io = IOBuffer()
    wire(io, r)
    String(take!(io))
end

"""
The run id (N48): the first line of `.weft/run` found in the document's folder
(QUARTO_DOCUMENT_PATH, else the working folder) or up to 8 parents; else WEFT_RUN
when it is not empty; else nothing. Read at each call, never kept.
"""
function run_id()
    d = abspath(get(ENV, "QUARTO_DOCUMENT_PATH", "") == "" ? pwd() : ENV["QUARTO_DOCUMENT_PATH"])
    for _ in 1:9
        f = joinpath(d, ".weft", "run")
        if isfile(f)
            try
                line = open(readline, f)
                isempty(strip(line)) || return String(line)
            catch
            end
        end
        up = dirname(d)
        up == d && break
        d = up
    end
    e = get(ENV, "WEFT_RUN", "")
    isempty(e) ? nothing : e
end

# the JSON of one check object (N23) of the block's own `checks`
function check_json(io::IO, c)
    print(io, "{\"text\":"); jstr(io, c.text)
    print(io, ",\"ok\":false,\"level\":"); jstr(io, c.level)
    print(io, ",\"why\":"); jopt(io, c.why)
    print(io, ",\"expr\":"); jstr(io, c.expr)
    print(io, ",\"value\":"); wire(io, c.value)
    print(io, ",\"line\":", c.line === nothing ? "null" : string(c.line))
    print(io, '}')
end

"The fenced block (N20): four backticks, the JSON on one line."
function block_text(values, checks = nothing)
    io = IOBuffer()
    print(io, "{\"weft\":1,\"lang\":\"julia\",\"run\":")
    r = run_id()
    r === nothing ? print(io, "null") : jstr(io, r)
    print(io, ",\"at\":", floor(Int, time()), ",\"values\":{")
    for (i, (name, rc)) in enumerate(values)
        i > 1 && print(io, ',')
        jstr(io, name); print(io, ':'); wire(io, rc)
    end
    print(io, '}')
    if checks !== nothing && !isempty(checks)
        print(io, ",\"checks\":[")
        for (i, c) in enumerate(checks)
            i > 1 && print(io, ',')
            check_json(io, c)
        end
        print(io, ']')
    end
    print(io, '}')
    string("````{.weft-values}\n", String(take!(io)), "\n````")
end

# ---- put (N70) ----------------------------------------------------------------------

E41(name) = string("`", name, "` is not a name weft can publish: ASCII letters, digits, _ and ., ",
                         "starting with a letter or _ (rule 1.12.1).")
E42(name, n) = string("`", name, "` is a list of ", n, " elements; weft publishes at most ",
                            MAX_LIST, " (rule 2.13.1).")

"""
    Weft.put(; name = value, ...)
    Weft.put(:name => value, ...)

Publish values by name. Each becomes a record of the classifier of record.jl (an
integer of any size is an int record; a value it refuses is published as its
error record). Nothing is published when a name is not a NAME or a list holds
more than 10000 elements (`PublishError`). A name given twice keeps its last
value. Returns `nothing`. On the julia engine the block is displayed; under knitr
the records wait for R; with no back end the block is printed.
"""
function put(pairs::Pair...; kw...)
    names = String[]
    recs = Dict{String, Rec}()
    function add(k, v)
        ks = k isa Symbol || k isa AbstractString ? String(k) : string(k)
        is_name(ks) || throw(PublishError(E41(ks)))
        r = classify(v)
        r.t == "list" && length(r.v) > MAX_LIST && throw(PublishError(E42(ks, length(r.v))))
        ks in names || push!(names, ks)
        recs[ks] = r
    end
    for p in pairs
        add(p.first, p.second)
    end
    for (k, v) in kw
        add(k, v)
    end
    publish([(n, recs[n]) for n in names])
    nothing
end

"""
    @put a b c

Publish each variable under its own name, in one block: `Weft.put(:a => a, ...)`.
"""
macro put(args...)
    isempty(args) && error("@put takes variable names: @put a b.")
    for a in args
        a isa Symbol || error("@put takes variable names: @put a b.")
    end
    :(put($([:($(QuoteNode(a)) => $(esc(a))) for a in args]...)))
end

function publish(values)
    k = kind()
    if k === :knitr
        for (n, r) in values
            push!(PUTS, n => wire_text(r))
        end
    elseif k === :engine
        display(Values(block_text(values)))
    else
        println(block_text(values))
    end
    nothing
end

# ---- @claim -----------------------------------------------------------------------

const E50 = "@claim needs at least one check."

# x as `.val` prints it (N8)
function recprint(r::Rec)
    r.t == "bool" && return r.v ? "true" : "false"
    r.t == "missing" && return string(r.why)
    r.t == "list" && return join((recprint(e) for e in r.v), ", ")
    string(r.v)
end

function valtext(x)
    r = classify(x)
    if r.t == "error"
        s = try repr(x) catch; string(typeof(x)) end
        return length(s) <= 80 ? s : first(s, 77) * "..."
    end
    recprint(r)
end

# "{Type}: {message}" for an exception raised by a check
function errtext(e)
    m = try
        hasproperty(e, :msg) ? string(getproperty(e, :msg)) : sprint(showerror, e)
    catch
        sprint(showerror, e)
    end
    string(nameof(typeof(e)), ": ", strip(first(split(m, '\n'))))
end

function _claim(level::Symbol, expr::String, value, checks, line = nothing)
    (level === :fail || level === :warn) || throw(ArgumentError("level is :fail or :warn."))
    failed = NamedTuple{(:text, :why, :detail), Tuple{String, Union{Nothing, String}, String}}[]
    val = nothing
    shown() = (val === nothing && (val = valtext(value)); val)
    for (text, f) in checks
        r = nothing
        why = nothing
        try
            r = f(value)
        catch e
            why = errtext(e)
        end
        if why !== nothing
            push!(failed, (text = text, why = why, detail = string(text, " was false (value ", shown(), "); ", why)))
        elseif r isa Bool
            r || push!(failed, (text = text, why = nothing, detail = string(text, " was false (value ", shown(), ")")))
        else
            w = string("gave a ", typeof(r), ", not true or false")
            push!(failed, (text = text, why = w, detail = string(text, " ", w)))
        end
    end
    isempty(failed) && return value
    k = kind()
    msg = string("weft: a claim failed: ", failed[1].detail, ".")
    if k === :knitr
        for f in failed
            push!(CLAIMS, (String(level), expr, f.detail))
        end
    elseif k === :engine
        # N57: the block is displayed (a cell that raises loses it, measured; so a failed claim
        # also prints it as text, which the filter reads)
        rv = classify(value)
        cks = [(text = f.text, level = String(level), why = f.why, expr = expr, value = rv, line = line)
               for f in failed]
        txt = block_text(Tuple{String, Rec}[], cks)
        display(Values(txt))
        if level === :fail
            # the same block as text, with a tilde fence: Quarto wraps a cell's printed output in a
            # backtick fence, which a backtick fence in the text would close (measured). The filter
            # reads this form (inst/quarto/weft.lua, printed_carrier).
            println("~~~~", chop(txt, head = 4, tail = 4), "~~~~")
        end
    end
    level === :fail && throw(ClaimFailed(msg))
    k === :none && @warn msg
    value
end

const COMPARISONS = (:<, :<=, :>, :>=, :(==), :!=)

# `_` in a check stands for the value: replace it by `h`
subst(x::Symbol, h) = x === :_ ? h : x
subst(x::Expr, h) = Expr(x.head, Any[subst(a, h) for a in x.args]...)
subst(x, h) = x

"""
    @claim x > 10
    @claim expr check... [level=:warn]

Check a value; return it when every check passes. With one argument, it is a
comparison (`<`, `<=`, `>`, `>=`, `==`, `!=`) whose left operand is the value.
With more, each further argument is a check in which `_` stands for the value of
the first. A failed check is recorded, then `Weft.ClaimFailed` is thrown; at
`level=:warn` it is recorded as a warned check and nothing is thrown.
"""
macro claim(args...)
    level = QuoteNode(:fail)
    rest = Any[]
    for a in args
        if a isa Expr && (a.head === :(=) || a.head === :kw) && length(a.args) == 2 && a.args[1] === :level
            level = a.args[2]
        else
            push!(rest, a)
        end
    end
    isempty(rest) && error(E50)
    h = gensym("claimed")
    if length(rest) == 1
        c = rest[1]
        (c isa Expr && c.head === :call && length(c.args) == 3 && c.args[1] in COMPARISONS) || error(E50)
        value = c.args[2]
        checks = [(string(c), Expr(:call, c.args[1], h, c.args[3]))]
    else
        value = rest[1]
        checks = [(string(c), subst(c, h)) for c in rest[2:end]]
    end
    text = "@claim " * join((string(a) for a in args), " ")
    file = string(__source__.file)
    line = any(endswith(file, e) for e in (".qmd", ".md", ".ipynb")) ? __source__.line : nothing
    items = Expr(:vect, [Expr(:tuple, t, esc(Expr(:->, h, Expr(:block, b)))) for (t, b) in checks]...)
    :(_claim($(esc(level)), $text, $(esc(value)), $items, $line))
end

end # module Weft
