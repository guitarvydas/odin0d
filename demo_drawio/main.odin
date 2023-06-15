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

leaf_echo_init :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("Echo (ID:%d)", counter)
    return zd.leaf_new (name_with_id, leaf_echo_proc, 0)
}

leaf_echo_proc :: proc(eh: ^zd.Eh, msg: zd.Message, data: any) {
    fmt.println(eh.name, "/", msg.port, "=", msg.datum)
    zd.send(eh, "output", msg)
}

Sleep_Data :: struct {
    init: time.Tick,
    msg:  string,
}

leaf_sleep_init :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("Sleep (ID:%d)", counter)
    return zd.leaf_new (name_with_id, leaf_sleep_proc, 0)
}

leaf_sleep_proc :: proc(eh: ^zd.Eh, msg: zd.Message, data: any) {
    TIMEOUT :: 1 * time.Second

    switch msg.port {
    case "wait":
        fmt.println(eh.name, "/", msg.port, "=", msg.datum)

        data := Sleep_Data {
            init = time.tick_now(),
            msg  = msg.datum.(string),
        }

        zd.yield(eh, "sleep", data)
    case "sleep":
        data := msg.datum.(Sleep_Data)

        elapsed := time.tick_since(data.init)
        if elapsed < TIMEOUT {
            zd.yield(eh, "sleep", data)
        } else {
            zd.send(eh, "output", data.msg)
        }
    }
}

main :: proc() {
    leaves: []reg.Leaf_Initializer = {
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

    fmt.println("--- Diagram: Sequential Routing ---")
    {
        main_container, ok := reg.get_component_instance(parts, "main")
        assert(ok, "Couldn't find main container... check the page name?")

        msg := zd.make_message("seq", "Hello Sequential!")
        main_container.handler(main_container, msg, 0)
        zd.print_output_list(main_container)
    }

    fmt.println("--- Diagram: Parallel Routing ---")
    {
        main_container, ok := reg.get_component_instance(parts, "main")
        assert(ok, "Couldn't find main container... check the page name?")

        msg := zd.make_message("par", "Hello Parallel!")
        main_container.handler(main_container, msg, 0)
        zd.print_output_list(main_container)
    }

    fmt.println("--- Diagram: Yield ---")
    {
        main_container, ok := reg.get_component_instance(parts, "main")
        assert(ok, "Couldn't find main container... check the page name?")

        msg := zd.make_message("yield", "Hello Yield!")
        main_container.handler(main_container, msg, 0)
        zd.print_output_list(main_container)
    }
}
