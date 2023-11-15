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
    fmt.println (d.repr ()) // compiler doesn't complain
    // fmt.println (d.repr (d)) // intended
}
