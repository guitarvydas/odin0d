package zd

import "core:container/queue"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:intrinsics"
import "core:log"

Bang :: struct {}


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
// `instance_data` is a pointer to any extra state data that the `leaf_handler`
// function may want whenever it is invoked again.
//
Eh_States :: enum { idle, active }
Eh :: struct {
    name:         string,
    input:        FIFO,
    output:       FIFO,
    children:     []^Eh,
    connections:  []Connector,
    handler:      #type proc(eh: ^Eh, message: Message),
    leaf_handler: rawptr, //#type proc(eh: ^Eh, message: Message($Datum)),
    instance_data:    rawptr, //#type proc(eh: ^Eh, message: Message($Datum), data: ^$Data),
    state:       Eh_States
}


// Creates a component that acts as a container. It is the same as a `Eh` instance
// whose handler function is `container_handler`.
make_container :: proc(name: string) -> ^Eh {
    eh := new(Eh)
    eh.name = name
    eh.handler = container_handler
    eh.state = .idle
    return eh
}

// Creates a new leaf component out of a handler function, and optionally a user
// data parameter that will be passed back to your handler when it is run.
make_leaf :: proc{
    make_leaf_simple,
    make_leaf_with_data,
}

// Creates a new leaf component out of a handler function.
make_leaf_simple :: proc(name: string, handler: proc(^Eh, Message)) -> ^Eh {
    eh := new(Eh)
    eh.name = name
    eh.handler = handler
    eh.state = .idle
    return eh
}

// Creates a new leaf component out of a handler function, and a data parameter
// that will be passed back to your handler when called.
make_leaf_with_data :: proc(name: string, data: ^$Data, handler: proc(^Eh, Message, ^Data)) -> ^Eh {
    leaf_handler_with_data :: proc(eh: ^Eh, message: Message) {
        handler := (proc(^Eh, Message, ^Data))(eh.leaf_handler)
        data := (^Data)(eh.instance_data)
        handler(eh, message, data)
    }

    eh := new(Eh)
    eh.name = name
    eh.handler = leaf_handler_with_data
    eh.leaf_handler = rawptr(handler)
    eh.instance_data = data
    eh.state = .idle
    return eh
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
container_handler :: proc(eh: ^Eh, message: Message) {
    route(eh, nil, message)
    for any_child_ready(eh) {
        step_children(eh)
    }
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
    container.state = .idle
    for child in container.children {
        msg: Message = make_message ("?", true)
        ok: bool

        switch {
        case child.input.len > 0:
            msg, ok = fifo_pop(&child.input)
	case child.state != .idle:
	    ok = true
	    msg = make_message (".", true)
        }

        if ok {
            log.debugf("INPUT  0x%p %s/%s(%s)", child, container.name, child.name, msg.port)
            child.handler(child, msg)
            destroy_message(msg)
        }

	if child.state == .active {
	    container.state = .active
	}

        for child.output.len > 0 {
            msg, _ = fifo_pop(&child.output)
            log.debugf("OUTPUT 0x%p %s/%s(%s)", child, container.name, child.name, msg.port)
            route(container, child, msg)
            destroy_message(msg)
        }
    }
}

tick :: proc (eh: ^Eh) {
    if eh.state != .idle {
	tick_msg := make_message (".", true)
	fifo_push (&eh.input, tick_msg)
    }
}

// Routes a single message to all matching destinations, according to
// the container's connection network.
route :: proc(container: ^Eh, from: ^Eh, message: Message) {
    was_sent := false // for checking that output went somewhere (at least during bootstrap)
    if message.port == "." {
	for child in container.children {
	    tick (child)
	}
	was_sent = true
    } else {
	from_sender := Sender{from, message.port}
	
	for connector in container.connections {
            if sender_eq(from_sender, connector.sender) {
		deposit(connector, message)
		was_sent = true
            }
	}
    }
    fmt.assertf (was_sent, "\n\n!!! message from %v dropped on floor: %v\n\n", from.name, message)
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
    return !fifo_is_empty(eh.output) || !fifo_is_empty(eh.input) || eh.state!= .idle || any_child_ready (eh)
}

any_of_my_children_ready :: proc (eh: ^Eh) -> bool {
    return any_child_ready (eh)
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

set_active :: proc (eh: ^Eh) {
    eh.state = .active
}

set_idle :: proc (eh: ^Eh) {
    eh.state = .idle
}

