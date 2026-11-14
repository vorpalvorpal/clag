# weft's Julia helpers (rules 1.11 and 2.12.15 to 2.12.21 of the spec, section J
# of dev/design-5.md). The module is defined once per R session, by weft, and is
# the only name weft adds to Julia's Main.
#
# It holds three things:
#   the reader   read(steps) classifies the Julia value at a path from Main by
#                its type and returns a typed record as JSON text, so that
#                JuliaCall's conversion never sees the value (a scalar
#                `missing` ends R when JuliaCall converts it);
#   the logger   install() wraps the global logger: every @warn and @error
#                record is noted, then handed on unchanged; drain() returns
#                the notes as JSON text and clears them (J3);
#   the includes install() also notes the path of every include() (J4);
#                included() returns them as JSON text.
#
# A record is a JSON object with the keys t, v, why, of, keys and type:
#   t     "bool" "int" "float" "string" "date" "list" "missing" "error"
#   v     bool: true or false; int: the digit string; float: repr(Float64(x));
#         string: the text; date: ISO; list: an array of scalar records
#   why   missing and error: the reason; for an error, the refusal message with
#         the subject written as the literal text {S}
#   of    lists: the kind of the elements after the promotion of J6
#   keys  the field names of a NamedTuple
#   type  Julia's string(typeof(x)), which names a type as Main sees it
# Nothing here assigns a name in Main or raises: a value that cannot be read is
# an error record.
module WeftGuest

using Logging

# the classifier is the package Weft's (N60): one record type, one classify()
include(joinpath(@__DIR__, "Weft", "src", "record.jl"))

# ---- the reader (J8) ---------------------------------------------------------------

# One step down from `obj`: a key when `obj` is a dictionary (a String key, else
# the Symbol key), else a field or property. Throws when there is none.
function step(obj, name::String)
    if obj isa AbstractDict
        haskey(obj, name) && return obj[name]
        s = Symbol(name)
        haskey(obj, s) && return obj[s]
        error("no key")
    end
    getproperty(obj, Symbol(name))
end

"""
The record at the path `steps` from Main, as JSON text. The first step is a name
in Main. A step that is not there gives {"t":"absent","at":<index of the step>}.
"""
function read(steps)::String
    names = steps isa AbstractString ? String[steps] : String[string(s) for s in steps]
    obj = nothing
    for (i, name) in enumerate(names)
        try
            if i == 1
                isdefined(Main, Symbol(name)) || return "{\"t\":\"absent\",\"at\":0}"
                obj = getfield(Main, Symbol(name))
            else
                obj = step(obj, name)
            end
        catch
            return "{\"t\":\"absent\",\"at\":$(i - 1)}"
        end
    end
    json(classify(obj))
end

# ---- the logger (J3) ---------------------------------------------------------------

const RECORDS = Tuple{String, String}[]

struct WeftLogger <: Logging.AbstractLogger
    inner::Logging.AbstractLogger
    limits::Dict{Any, Int}
end

Logging.min_enabled_level(l::WeftLogger) = min(Logging.min_enabled_level(l.inner), Logging.Warn)
Logging.catch_exceptions(l::WeftLogger) = Logging.catch_exceptions(l.inner)
function Logging.shouldlog(l::WeftLogger, level, _module, group, id)
    level >= Logging.Warn || Logging.shouldlog(l.inner, level, _module, group, id)
end

function Logging.handle_message(l::WeftLogger, level, message, _module, group, id, file, line; kwargs...)
    if level >= Logging.Warn
        maxlog = get(kwargs, :maxlog, nothing)
        if maxlog isa Integer
            left = get(l.limits, id, Int(maxlog))
            l.limits[id] = left - 1
            left > 0 || return nothing
        end
        push!(RECORDS, (level >= Logging.Error ? "error" : "warning", string(message)))
    end
    if Logging.shouldlog(l.inner, level, _module, group, id)
        Logging.handle_message(l.inner, level, message, _module, group, id, file, line; kwargs...)
    end
    nothing
end

"The notes of @warn and @error records since the last call, as JSON text; the notes are cleared."
function drain()::String
    io = IOBuffer()
    print(io, '[')
    for (i, (c, t)) in enumerate(RECORDS)
        i > 1 && print(io, ',')
        print(io, '[')
        jstr(io, c)
        print(io, ',')
        jstr(io, t)
        print(io, ']')
    end
    print(io, ']')
    empty!(RECORDS)
    String(take!(io))
end

# ---- the includes (J4) -------------------------------------------------------------

const INCLUDED = String[]

function on_include(mod, path)
    try
        p = String(path)
        isvalid(p) && !(p in INCLUDED) && push!(INCLUDED, p)
    catch
    end
    nothing
end

"The path of every include() since install(), as JSON text."
function included()::String
    io = IOBuffer()
    print(io, '[')
    for (i, p) in enumerate(INCLUDED)
        i > 1 && print(io, ',')
        jstr(io, p)
    end
    print(io, ']')
    String(take!(io))
end

# ---- the package Weft under knitr (N56, N60) ----------------------------------------

"True once R has noted that Julia is running chunks of a knit; Weft reads it when it loads."
const KNITR = Ref(false)

"Add the folder that holds the package Weft to LOAD_PATH, once, at the end."
function add_load_path(dir::String)
    d = abspath(dir)
    any(p -> p isa AbstractString && abspath(p) == d, LOAD_PATH) || push!(LOAD_PATH, d)
    nothing
end

# the module of the package Weft, loaded by whatever name the author gave it, or nothing
function weft_module()
    for (id, m) in Base.loaded_modules
        id.name == "Weft" && return m
    end
    nothing
end

"True when R collects failed claims in the chunk about to run (chunk_claims: collect, GN3); R sets it before each Julia chunk."
const COLLECT = Ref(false)

"A Julia chunk of a knit is about to run: Weft records claims for R (Weft.use_knitr()). `collect` says whether a failed claim is collected, not thrown."
function mark_knitr(collect::Bool = false)
    KNITR[] = true
    COLLECT[] = collect
    m = weft_module()
    m === nothing || m.use_knitr()
    nothing
end

"The notes of failed and warned claims since the last call, as JSON text; cleared."
function drain_claims()::String
    m = weft_module()
    m === nothing ? "[]" : m.drain_claims()
end

"The records Weft.put published since the last call, as JSON text [[name, record text], ...]; cleared."
function drain_puts()::String
    m = weft_module()
    m === nothing ? "[]" : m.drain_puts()
end

const INSTALLED = Ref(false)

"Wrap the global logger and note include() calls. Once per session."
function install()
    INSTALLED[] && return nothing
    INSTALLED[] = true
    push!(Base.include_callbacks, on_include)
    Logging.global_logger(WeftLogger(Logging.global_logger(), Dict{Any, Int}()))
    nothing
end

end # module WeftGuest
