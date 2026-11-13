# Methods for a dictionary

A `weft_dict` is read-only, and read by exact key (see
[`read_dict()`](https://vorpalvorpal.github.io/weft/reference/read_dict.md)).

## Usage

``` r
# S3 method for class 'weft_dict'
x$name

# S3 method for class 'weft_dict'
x[[i, ...]]

# S3 method for class 'weft_dict'
x[...]

# S3 method for class 'weft_dict'
x$name <- value

# S3 method for class 'weft_dict'
x[[i]] <- value

# S3 method for class 'weft_dict'
x[i] <- value

# S3 method for class 'weft_dict'
names(x) <- value

# S3 method for class 'weft_dict'
names(x)

# S3 method for class 'weft_dict'
as.list(x, ...)

# S3 method for class 'weft_dict'
print(x, ...)
```

## Arguments

- x:

  A `weft_dict`.

- name, i:

  A key.

- ...:

  Not used.

- value:

  Not used: a dictionary cannot be assigned to.

## Value

`$` and `[[` return the value;
[`print()`](https://rdrr.io/r/base/print.html) returns `x` invisibly;
[`as.list()`](https://rdrr.io/r/base/list.html) returns a plain named
list of the values.
