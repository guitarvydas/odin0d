package zd

import "core:strings"
import "core:mem"
import "core:runtime"
import "core:os"
import "core:fmt"

Datum :: struct {
    data: any,
    clone:    #type proc (^Datum) -> ^Datum,
    reclaim:  #type proc (^Datum),
    asString: #type proc (^Datum) -> string,
    kind:     #type proc ()       -> string
}


new_datum_string :: proc (s : string) -> ^Datum {
    string_kind :: proc () -> string {
	return "string"
    }
    string_in_heap := new (string)
    string_in_heap^ = strings.clone (s)
    datum_in_heap := new (Datum)
    datum_in_heap.data = string_in_heap^
    datum_in_heap.clone = clone_datum_string
    datum_in_heap.reclaim = reclaim_datum_string    
    datum_in_heap.asString = asString_datum_string    
    datum_in_heap.kind = string_kind
    return datum_in_heap
}

clone_datum_string :: proc (src: ^Datum) -> ^Datum {
    cloned_string_in_heap := new (string)
    temp_datum : Datum = src^
    a := temp_datum.data
    temp_str := strings.clone (temp_datum.data.(string))
    cloned_string_in_heap^ = temp_str
    datum_in_heap := new (Datum)
    datum_in_heap = src
    datum_in_heap.data = cloned_string_in_heap^
    return datum_in_heap
}

reclaim_datum_string :: proc (src: ^Datum) {
    // TODO
    // Q: do we ever need to reclaim the string, or is the Biblical Flood method of GC enough?
}

asString_datum_string :: proc (self : ^Datum) -> string {
    return self.data.(string)
}



new_datum_bang :: proc () -> ^Datum {
    my_kind :: proc () -> string {
	return "bang"
    }
    p := new (Datum)
    p.data = true
    p.clone = clone_datum_bang
    p.reclaim = reclaim_datum_bang
    p.asString = asString_datum_bang    
    p.kind = my_kind
    return p
}

clone_datum_bang :: proc (src: ^Datum) -> ^Datum {
    return new_datum_bang ()
}

reclaim_datum_bang :: proc (src: ^Datum) {
}

asString_datum_bang :: proc (src : ^Datum) -> string {
    return "!"
}

///

new_datum_tick :: proc () -> ^Datum {
    my_kind :: proc () -> string {
	return "tick"
    }
    p := new_datum_bang ()
    p.kind = my_kind
    return p
}

///
new_datum_bytes :: proc (b : []byte) -> ^Datum {
    my_kind :: proc () -> string {
	return "bytes"
    }
    p := new (Datum)
    p.data = clone_bytes (b)
    p.clone = clone_datum_bytes
    p.reclaim = reclaim_datum_bytes
    p.asString = asString_datum_v
    p.kind = my_kind
    return p
}

clone_datum_bytes :: proc (src: ^Datum) -> ^Datum {
    p := new (Datum)
    p = src
    p.data = clone_bytes (src.data.([]byte))
    return p
}

reclaim_datum_bytes :: proc (src: ^Datum) {
    // TODO
}

asString_datum_v :: proc (src : ^Datum) -> string {
    return fmt.aprintf ("%v", src.data)
}


clone_bytes :: proc(b: any) -> any {
    b_ti := type_info_of(b.id)

    new_b_ptr := mem.alloc(b_ti.size, b_ti.align) or_else panic("data_ptr alloc")
    mem.copy_non_overlapping(new_b_ptr, b.data, b_ti.size)

    return any{new_b_ptr, b.id},
}


//
new_datum_handle :: proc (h : os.Handle) -> ^Datum {
    my_kind :: proc () -> string {
	return "handle"
    }
    p := new (Datum)
    p.data = h
    p.clone = clone_handle
    p.reclaim = reclaim_handle
    p.asString = asString_datum_v
    p.kind = my_kind
    return p
}

clone_handle :: proc (src: ^Datum) -> ^Datum {
    p := new (Datum)
    p = src
    p.data = src.data.(os.Handle)
    return p
}

reclaim_handle :: proc (src: ^Datum) {
    // TODO
}
