# weft for Julia: @claim (rules N55 and N56 of dev/design-6.md), and, in later
# packages, put and the julia engine's back end.
#
#     using Weft
#     @claim n > 10
#     @claim mean(d) (_ > 0.5) (_ < 9)
#
# Under a weft knit (JuliaCall in an R knit) R puts this package's folder on
# LOAD_PATH, so `using Weft` loads this copy with nothing to install, and
# calls use_knitr(). A failed check is then noted in CLAIMS; R drains the notes
# after the chunk (drain_claims()) and adds each to the knit's failures or
# warned checks. No RCall call is made.
module Weft

include("record.jl")

export @claim

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

const BACKEND = Ref(:none)
const CLAIMS = Tuple{String, String, String}[]

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

function _claim(level::Symbol, expr::String, value, checks)
    (level === :fail || level === :warn) || throw(ArgumentError("level is :fail or :warn."))
    failed = String[]
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
            push!(failed, string(text, " was false (value ", shown(), "); ", why))
        elseif r isa Bool
            r || push!(failed, string(text, " was false (value ", shown(), ")"))
        else
            push!(failed, string(text, " gave a ", typeof(r), ", not true or false"))
        end
    end
    isempty(failed) && return value
    if BACKEND[] === :knitr
        for d in failed
            push!(CLAIMS, (String(level), expr, d))
        end
    end
    msg = string("weft: a claim failed: ", failed[1], ".")
    level === :fail && throw(ClaimFailed(msg))
    BACKEND[] === :knitr || @warn msg
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
    items = Expr(:vect, [Expr(:tuple, t, esc(Expr(:->, h, Expr(:block, b)))) for (t, b) in checks]...)
    :(_claim($(esc(level)), $text, $(esc(value)), $items))
end

end # module Weft
