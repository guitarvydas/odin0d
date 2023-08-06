package zd

import "core:fmt"
import "core:log"
import "core:mem"
import "core:strings"

// Message passed to a leaf component.
//
// `port` refers to the name of the incoming or outgoing port of this component.
// `datum` is the data attached to this message.
Message :: struct {
    port:  string,
    datum: any,
}

// Utility for making a `Message`. Used to safely "seed" messages
// entering the very top of a network.

// there are 3 places that parts of a message can be allocated: temp, heap, literal pool
// this version assumes that ports are always string literals and that .datums never contain pointers
make_message :: proc(port: string, data: $Data) -> Message {
    data_ptr := new_clone(data)
    data_id := typeid_of(Data)

    return {
        port  = port,
        datum = any{data_ptr, data_id},
    }
}

// Clones a message. Primarily used internally for "fanning out" a message to multiple destinations.
message_clone :: proc(message: Message) -> Message {
    new_message := Message {
        port = message.port,
        datum = clone_datum(message.datum),
    }
    return new_message
}

// Clones the datum portion of the message.
clone_datum :: proc(datum: any) -> any {
    datum_ti := type_info_of(datum.id)

    new_datum_ptr := mem.alloc(datum_ti.size, datum_ti.align) or_else panic("data_ptr alloc")
    mem.copy_non_overlapping(new_datum_ptr, datum.data, datum_ti.size)

    return any{new_datum_ptr, datum.id},
}

// Frees a message.
destroy_message :: proc(msg: Message) {
    destroy_datum (msg.datum)
}

destroy_datum :: proc (d: any) {
    log.errorf("wanted: destroy datum %v, but don't know how yet\n")
}
