/*

This example demonstrates taking a `.drawio` file and interpreting it at
runtime into a control flow configuration on top of the 0d runtime.

You can make edits to `example.drawio`, and re-run the program without
recompiling to observe changes.

See `README.md` for more information on the implemented reference diagram
syntax.

*/
package demo_drawio

import "core:fmt"
import "core:time"
import zd "../0d"
import reg "../registry0d"

Eh                :: zd.Eh
Message           :: zd.Message
make_container    :: zd.make_container
make_message      :: zd.make_message
make_leaf         :: zd.make_leaf
send              :: zd.send
yield             :: zd.yield
print_output_list :: zd.print_output_list

leaf_Z_init :: proc(name: string) -> ^Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("Z (ID:%d)", counter)
    return make_leaf(name_with_id, leaf_Z_proc)
}

leaf_Z_proc :: proc(eh: ^Eh, msg: Message) {
    fmt.println(eh.name, "/", msg.port, "<receives>", msg.datum)
    send(eh, "childout", msg)
    // problem: "childout" is NC, but send delivers this message to "cin"
}

leaf_echo_init :: proc(name: string) -> ^Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("Echo (ID:%d)", counter)
    return make_leaf(name_with_id, leaf_echo_proc)
}

leaf_echo_proc :: proc(eh: ^Eh, msg: Message) {
    fmt.println(eh.name, "/", msg.port, "=", msg.datum)
    send(eh, "output", msg)
}

Sleep_Data :: struct {
    init: time.Tick,
    msg:  string,
}

leaf_sleep_init :: proc(name: string) -> ^Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("Sleep (ID:%d)", counter)
    return make_leaf(name_with_id, leaf_sleep_proc)
}

leaf_sleep_proc :: proc(eh: ^Eh, msg: Message) {
    TIMEOUT :: 1 * time.Second

    switch msg.port {
    case "wait":
        fmt.println(eh.name, "/", msg.port, "=", msg.datum)

        data := Sleep_Data {
            init = time.tick_now(),
            msg  = msg.datum.(string),
        }

        yield(eh, "sleep", data)
    case "sleep":
        data := msg.datum.(Sleep_Data)

        elapsed := time.tick_since(data.init)
        if elapsed < TIMEOUT {
            yield(eh, "sleep", data)
        } else {
            send(eh, "output", data.msg)
        }
    }
}

main :: proc() {
    leaves: []reg.Leaf_Initializer = {
        // {
        //     name = "Z",
        //     init = leaf_Z_init,
        // },
        {
            name = "Echo",
            init = leaf_echo_init,
        },
        {
            name = "Sleep",
            init = leaf_sleep_init,
        },
    }

    parts := reg.make_component_registry(leaves, "example.drawio")

    fmt.println("--- Diagram: Test NC ---")
    {
        main_container, ok := reg.get_component_instance(parts, "main")
        assert(ok, "Couldn't find main container... check the page name?")

        msg := make_message("cin", "Hello Sequential!")
        main_container.handler(main_container, msg)
        print_output_list(main_container)
    }
}
