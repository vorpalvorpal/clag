# The one classifier of Julia values (rules 1.11 and 2.12.15 of the spec, N60 of
# dev/design-6.md). It is included, inside a module, by Weft.jl and by
# WeftGuest.jl (the reader R uses under knitr), so that @claim and the reader
# make one record. It holds the record type, classify() and the JSON text of a
# record; it assigns no name outside the module that includes it.
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

using Dates

struct Rec
    t::String
    v::Any
    why::Union{Nothing, String}
    of::Union{Nothing, String}
    keys::Union{Nothing, Vector{String}}
    type::String
end

tname(x) = string(typeof(x))

rec(t, v, x) = Rec(t, v, nothing, nothing, nothing, tname(x))
missing_rec(why, x) = Rec("missing", nothing, why, nothing, nothing, tname(x))
error_rec(why, T) = Rec("error", nothing, why, nothing, nothing, T)

const KINDNAMES = Dict("int" => "integer", "float" => "float", "bool" => "bool",
                       "string" => "string", "date" => "date")

iscontainer(x) = x isa AbstractArray || x isa Tuple || x isa NamedTuple ||
                 x isa AbstractDict || x isa AbstractSet

function utf8_error(T)
    error_rec("{S} is a Julia $T that is not valid UTF-8 text (rule 1.11.5).", T)
end

function refuse_exact(T)
    error_rec("{S} is a Julia $T, which R cannot hold exactly. Convert it in Julia with " *
              "Float64(), and round it there if it should print as written (rule 1.11.2).", T)
end

# the record of a value that is not a container
function scalar(x)::Rec
    T = tname(x)
    x === missing && return missing_rec("missing", x)
    x === nothing && return missing_rec("nothing", x)
    x isa Bool && return rec("bool", x, x)
    x isa Integer && return rec("int", string(x), x)
    x isa BigFloat && return refuse_exact(T)
    if x isa AbstractFloat
        f = Float64(x)
        isnan(f) && return missing_rec("a float NaN", x)
        isinf(f) && return missing_rec("a float infinity", x)
        return rec("float", repr(f), x)
    end
    (x isa Rational || x isa Irrational) && return refuse_exact(T)
    if x isa AbstractString
        isvalid(x) || return utf8_error(T)
        return rec("string", String(x), x)
    end
    if x isa AbstractChar
        isvalid(x) || return utf8_error(T)
        return rec("string", string(x), x)
    end
    if x isa Symbol
        s = String(x)
        isvalid(s) || return utf8_error(T)
        return rec("string", s, x)
    end
    x isa Date && return rec("date", string(x), x)
    x isa DateTime &&
        return error_rec("{S} is a Julia $T, which holds a date and a time; weft reads a " *
                         "date. Convert it in Julia, in the time zone you mean, with " *
                         "Dates.Date() (rule 1.11.6).", T)
    error_rec("{S} is a Julia $T, which weft does not read as a value. Bind a Bool, an " *
              "integer, a float, a String, a Date, or a vector of one of these " *
              "(rule 1.11.1).", T)
end

function listrec(items, container, keys)::Rec
    T = tname(container)
    recs = Rec[]
    for el in items
        if iscontainer(el)
            return error_rec("{S} is a Julia $T that holds a $(tname(el)); weft reads a " *
                             "flat list (rule 1.11.4).", T)
        end
        r = scalar(el)
        r.t == "error" && return r
        push!(recs, r)
    end
    kinds = String[]
    for r in recs
        (r.t != "missing" && !(r.t in kinds)) && push!(kinds, r.t)
    end
    of = if length(kinds) <= 1
        isempty(kinds) ? "missing" : kinds[1]
    elseif Set(kinds) == Set(["int", "float"])
        "float"
    else
        return error_rec("{S} is a Julia $T whose elements are of more than one kind (" *
                         join([KINDNAMES[k] for k in kinds], ", ") * "); weft reads a list " *
                         "whose elements are all of one kind (rule 1.11.4).", T)
    end
    Rec("list", recs, nothing, of, keys, T)
end

function classify_value(x)::Rec
    if x isa AbstractArray
        d = ndims(x)
        d == 0 && return classify_value(x[])
        d >= 2 && return error_rec("{S} is a Julia array of $d dimensions; weft reads a " *
                                   "flat list (rule 1.11.4).", tname(x))
        return listrec(collect(x), x, nothing)
    end
    x isa Tuple && return listrec(collect(x), x, nothing)
    x isa NamedTuple && return listrec(collect(values(x)), x, String[string(k) for k in keys(x)])
    if x isa AbstractDict || x isa AbstractSet
        T = tname(x)
        return error_rec("{S} is a Julia $T, which has no order. Bind a NamedTuple, or a " *
                         "sorted vector, in a Julia chunk (rule 1.11.4).", T)
    end
    scalar(x)
end

function classify(x)::Rec
    try
        classify_value(x)
    catch e
        T = try tname(x) catch; "value" end
        error_rec("{S} is a Julia $T that weft could not read ($(typeof(e))); weft reads " *
                  "a Bool, an integer, a float, a String, a Date, or a vector of one of " *
                  "these (rule 1.11.1).", T)
    end
end

# ---- JSON text ---------------------------------------------------------------------

function jstr(io::IO, s::AbstractString)
    print(io, '"')
    for c in s
        if c == '"'
            print(io, "\\\"")
        elseif c == '\\'
            print(io, "\\\\")
        elseif c == '\n'
            print(io, "\\n")
        elseif c == '\r'
            print(io, "\\r")
        elseif c == '\t'
            print(io, "\\t")
        elseif !isvalid(c)
            print(io, "\\ufffd")
        elseif c < ' '
            print(io, "\\u", lpad(string(UInt16(c), base = 16), 4, '0'))
        else
            print(io, c)
        end
    end
    print(io, '"')
end

jopt(io, x::Nothing) = print(io, "null")
jopt(io, x::AbstractString) = jstr(io, x)

function emit(io::IO, r::Rec)
    print(io, "{\"t\":"); jstr(io, r.t)
    print(io, ",\"v\":")
    v = r.v
    if v === nothing
        print(io, "null")
    elseif v isa Bool
        print(io, v ? "true" : "false")
    elseif v isa String
        jstr(io, v)
    else
        print(io, '[')
        for (i, el) in enumerate(v)
            i > 1 && print(io, ',')
            emit(io, el)
        end
        print(io, ']')
    end
    print(io, ",\"why\":"); jopt(io, r.why)
    print(io, ",\"of\":"); jopt(io, r.of)
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
    print(io, ",\"type\":"); jstr(io, r.type)
    print(io, '}')
end

function json(r::Rec)
    io = IOBuffer()
    emit(io, r)
    String(take!(io))
end
