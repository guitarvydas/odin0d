## Context
Compiler doesn't raise an error when a method (proc), declared in a `struct` to take a pointer parameter, is called with no arguments.

`d.repr ()` is allowed, yet the proc (`repr`) is declared to need one argument i.e. `repr: #type proc (^Datum) -> string`
## Expected Behavior
`d.repr ()` should produce an error message
## Current Behavior
`d.repr ()` compiles without error
## Steps to Reproduce
compile and run
```
package play
import "core:fmt"

Datum :: struct {
    repr:     #type proc (^Datum) -> string,
}

repr_datum :: proc (self : ^Datum) -> string {
    return fmt.aprintf ("repr %v", self)
}

make_datum :: proc () -> ^Datum {
    result := new (Datum)
    result.repr = repr_datum
    return result
}

main :: proc () {
    d := make_datum ()
    fmt.println (d.repr ()) // compiler doesn't complain, repr receives nil as its arg
    // fmt.println (d.repr (d)) // intended
}
```
