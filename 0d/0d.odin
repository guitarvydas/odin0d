package zd

import "core:container/queue"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:intrinsics"
import "core:log"

// Data for an asyncronous component - effectively, a function with input
// and output queues of messages.
//
// Components can either be a user-supplied function ("leaf"), or a "container"
// that routes messages to child components according to a list of connections
// that serve as a message routing table.
//
// Child components themselves can be leaves or other containers.
//
// `handler` invokes the code that is attached to this component. For leaves, it
// is a wrapper function around `leaf_handler` that will perform a type check
// before calling the user's function. For containers, `handler` is a reference
// to `container_handler`, which will dispatch messages to its children.
//
// `leaf_data` is a pointer to any extra state data that the `leaf_handler`
// function may want whenever it is invoked again.
//
// `state` is a free integer that can be used for writing leaves that act as
// state machines. There is a convenience proc `set_state` that will do the
// cast for you when writing.
Eh :: struct {
    name:         string,
    input:        FIFO,
    output:       FIFO,
    yield:        FIFO,
    data:	  any,
    children:     []^Eh,
    connections:  []Connector,
    handler:      #type proc(eh: ^Eh, message: Message, data: any),
    state:        int,
}

// Message passed to a leaf component.
//
// `port` refers to the name of the incoming port to this component.
// `datum` is the data attached to this message.
Message :: struct {
    port:  string,
    datum: any,
}

// Creates a component that acts as a container. It is the same as a `Eh` instance
// whose handler function is `container_handler`.
make_container :: proc(name: string) -> ^Eh {
    eh := new(Eh)
    eh.name = name
    eh.handler = container_handler
    return eh
}

leaf_new :: proc(name: string, handler: proc(^Eh, Message, any), data: any) -> ^Eh {
    eh := new(Eh)
    eh.name = name
    eh.handler = handler
    eh.data = data
    return eh
}

// Utility for making a `Message`. Used to safely "seed" messages
// entering the very top of a network.
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
        datum = clone_datum(message),
    }
    return new_message
}

// Clones the datum portion of the message.
clone_datum :: proc(message: Message) -> any {
    datum_ti := type_info_of(message.datum.id)

    new_datum_ptr := mem.alloc(datum_ti.size, datum_ti.align) or_else panic("data_ptr alloc")
    mem.copy_non_overlapping(new_datum_ptr, message.datum.data, datum_ti.size)

    return any{new_datum_ptr, message.datum.id},
}

// Frees a message.
destroy_message :: proc(msg: Message) {
    free(msg.datum.data)
}

// Sends a message on the given `port` with `data`, placing it on the output
// of the given component.
send :: proc(eh: ^Eh, port: string, data: $Data) {
    when Data == any {
        msg := Message {
            port  = port,
            datum = clone_datum(data),
        }
    } else {
        msg := make_message(port, data)
    }
    fifo_push(&eh.output, msg)
}

// Enqueues a message that will be returned to this component.
// This can be used to suspend leaf execution while, e.g. IO, completes
// in the background.
//
// NOTE(z64): this functionality is an active area of research; we are
// exploring how to best expose an API that allows for concurrent IO etc.
// while staying in-line with the principles of the system.
yield :: proc(eh: ^Eh, port: string, data: $Data) {
    msg := make_message(port, data)
    fifo_push(&eh.yield, msg)
}

// Returns a list of all output messages on a container.
// For testing / debugging purposes.
output_list :: proc(eh: ^Eh, allocator := context.allocator) -> []Message {
    list := make([]Message, eh.output.len)

    iter := make_fifo_iterator(&eh.output)
    for msg, i in fifo_iterate(&iter) {
        list[i] = msg
    }

    return list
}

// The default handler for container components.
container_handler :: proc(eh: ^Eh, message: Message, dontcare: any) {
    route(eh, nil, message)
    for any_child_ready(eh) {
        step_children(eh)
    }
}

// Sets the state variable on the Eh instance to the integer value of the
// given enum.
set_state :: #force_inline proc(eh: ^Eh, state: $State)
where
    intrinsics.type_is_enum(State)
{
    eh.state = int(state)
}

// Frees the given container and associated data.
destroy_container :: proc(eh: ^Eh) {
    drain_fifo :: proc(fifo: ^FIFO) {
        for fifo.len > 0 {
            msg, _ := fifo_pop(fifo)
            destroy_message(msg)
        }
    }
    drain_fifo(&eh.input)
    drain_fifo(&eh.output)
    free(eh)
}

// Wrapper for corelib `queue.Queue` with FIFO semantics.
FIFO       :: queue.Queue(Message)
fifo_push  :: queue.push_back
fifo_pop   :: queue.pop_front_safe

fifo_is_empty :: proc(fifo: FIFO) -> bool {
    return fifo.len == 0
}

FIFO_Iterator :: struct {
    q:   ^FIFO,
    idx: int,
}

make_fifo_iterator :: proc(q: ^FIFO) -> FIFO_Iterator {
    return {q, 0}
}

fifo_iterate :: proc(iter: ^FIFO_Iterator) -> (item: Message, idx: int, ok: bool) {
    if iter.q.len == 0 {
        ok = false
        return
    }

    i := (uint(iter.idx)+iter.q.offset) % len(iter.q.data)
    if i < iter.q.len {
        ok = true
        idx = iter.idx
        iter.idx += 1
        #no_bounds_check item = iter.q.data[i]
    }
    return
}

// Routing connection for a container component. The `direction` field has
// no affect on the default message routing system - it is there for debugging
// purposes, or for reading by other tools.
Connector :: struct {
    direction: Direction,
    sender:    Sender,
    receiver:  Receiver,
}

Direction :: enum {
    Down,
    Across,
    Up,
    Through,
}

// `Sender` is used to "pattern match" which `Receiver` a message should go to,
// based on component ID (pointer) and port name.
Sender :: struct {
    component: ^Eh,
    port:      string,
}

// `Receiver` is a handle to a destination queue, and a `port` name to assign
// to incoming messages to this queue.
Receiver :: struct {
    queue: ^FIFO,
    port:  string,
}

// Checks if two senders match, by pointer equality and port name matching.
sender_eq :: proc(s1, s2: Sender) -> bool {
    return s1.component == s2.component && s1.port == s2.port
}

// Delivers the given message to the receiver of this connector.
deposit :: proc(c: Connector, message: Message) {
    new_message := message_clone(message)
    new_message.port = c.receiver.port
    fifo_push(c.receiver.queue, new_message)
}

step_children :: proc(container: ^Eh) {
    for child in container.children {
        msg: Message
        ok: bool

        switch {
        case child.yield.len > 0:
            msg, ok = fifo_pop(&child.yield)
        case child.input.len > 0:
            msg, ok = fifo_pop(&child.input)
        }

        if ok {
            log.debugf("INPUT  0x%p %s/%s(%s)", child, container.name, child.name, msg.port)
            child.handler(child, msg, 0)
            destroy_message(msg)
        }

        for child.output.len > 0 {
            msg, _ = fifo_pop(&child.output)
            log.debugf("OUTPUT 0x%p %s/%s(%s)", child, container.name, child.name, msg.port)
            route(container, child, msg)
            destroy_message(msg)
        }
    }
}

// Routes a single message to all matching destinations, according to
// the container's connection network.
route :: proc(container: ^Eh, from: ^Eh, message: Message) {
    from_sender := Sender{from, message.port}

    for connector in container.connections {
        if sender_eq(from_sender, connector.sender) {
            deposit(connector, message)
        }
    }
}

any_child_ready :: proc(container: ^Eh) -> (ready: bool) {
    for child in container.children {
        if child_is_ready(child) {
            return true
        }
    }
    return false
}

child_is_ready :: proc(eh: ^Eh) -> bool {
    return !fifo_is_empty(eh.output) || !fifo_is_empty(eh.input) || !fifo_is_empty(eh.yield)
}

// Utility for printing an array of messages.
print_output_list :: proc(eh: ^Eh) {
    write_rune   :: strings.write_rune
    write_string :: strings.write_string

    sb: strings.Builder
    defer strings.builder_destroy(&sb)

    write_rune(&sb, '[')

    iter := make_fifo_iterator(&eh.output)
    for msg, idx in fifo_iterate(&iter) {
        if idx > 0 {
            write_string(&sb, ", ")
        }
        fmt.sbprintf(&sb, "{{%s, %v}", msg.port, msg.datum)
    }
    strings.write_rune(&sb, ']')

    fmt.println(strings.to_string(sb))
}
