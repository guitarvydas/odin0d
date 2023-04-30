package demo_drawio

import "core:fmt"
import "core:strings"
import "core:time"
import zd "../0d"

Eh                :: zd.Eh
Message           :: zd.Message
make_container    :: zd.make_container
make_message      :: zd.make_message
make_leaf         :: zd.make_leaf
send              :: zd.send
yield             :: zd.yield
print_output_list :: zd.print_output_list

leaf_echo_init :: proc(name: string) -> ^Eh {
    @(static) counter := 0
    counter += 1

    name := fmt.aprintf("Echo (ID:%d)", counter)
    return make_leaf(name, leaf_echo_proc)
}

leaf_echo_proc :: proc(eh: ^Eh, msg: Message(string)) {
    fmt.println(eh.name, "/", msg.port, "=", msg.datum)
    send(eh, "output", msg.datum)
}

Sleep_Data :: struct {
    init: time.Tick,
    msg:  string,
}

leaf_sleep5_init :: proc(name: string) -> ^Eh {
    @(static) counter := 0
    counter += 1

    name := fmt.aprintf("Sleep (ID:%d)", counter)
    return make_leaf(name, leaf_sleep5_proc)
}

leaf_sleep5_proc :: proc(eh: ^Eh, msg: Message(any)) {
    TIMEOUT :: 5 * time.Second

    switch msg.port {
    case "wait":
        fmt.println(eh.name, "/", msg.port, "=", msg.datum)
        data := Sleep_Data {
            init = time.tick_now(),
            msg  = msg.datum.(string),
        }

        send(eh, "sleep", data)

    case "retry":
        data := msg.datum.(Sleep_Data)

        elapsed := time.tick_since(data.init)
        if elapsed < TIMEOUT {
            send(eh, "sleep", data)
        } else {
	    fmt.println()
	    fmt.println("Finally! ", eh.name, "/", msg.port)
            send(eh, "output", data.msg)
        }
    }
}

main :: proc() {
    leaves: []Leaf_Initializer = {
        {
            name = "Echo",
            init = leaf_echo_init,
        },
        {
            name = "Sleep5",
            init = leaf_sleep5_init,
        },
    }

    reg := make_component_registry(leaves, "example.drawio")

    fmt.println("--- Diagram: Sequential Routing ---")
    {
        main_container, ok := get_component_instance(reg, "main")
        assert(ok, "Couldn't find main container... check the page name?")

        msg := make_message("seq", "Hello Sequential!")
        main_container.handler(main_container, msg)
        print_output_list(main_container)
    }

    fmt.println("--- Diagram: Parallel Routing ---")
    {
        main_container, ok := get_component_instance(reg, "main")
        assert(ok, "Couldn't find main container... check the page name?")

        msg := make_message("par", "Hello Parallel!")
        main_container.handler(main_container, msg)
        print_output_list(main_container)
    }

    fmt.println("--- Diagram: Yield ---")
    {
        main_container, ok := get_component_instance(reg, "main")
        assert(ok, "Couldn't find main container... check the page name?")

        msg := make_message("yield", "Hello Yield!")
        main_container.handler(main_container, msg)
        print_output_list(main_container)
    }
}
