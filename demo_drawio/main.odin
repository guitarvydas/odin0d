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
print_output_list :: zd.print_output_list

leaf_echo_init :: proc(name: string) -> ^Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("Echo (ID:%d)", counter)
    return make_leaf(name_with_id, leaf_echo_proc)
}

leaf_echo_proc :: proc(eh: ^Eh, msg: Message) {
    fmt.println(eh.name, "/", msg.port, "=", msg.datum)
    send(eh, "output", msg.datum)
}

Sleep_Data :: struct {
    init: time.Tick,
    msg:  string,
}

leaf_sleep_init :: proc(name: string) -> ^Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("Sleep (ID:%d)", counter)
    d := new (Sleep_Data)
    return zd.make_leaf_with_data(name_with_id, d, leaf_sleep_proc)
}

leaf_sleep_proc :: proc(eh: ^Eh, msg: Message, d: ^Sleep_Data) {
    if (msg.port != ".") {
	fmt.println ("leaf_sleep_proc: ", msg)
    }
    TIMEOUT :: 1 * time.Second

    switch msg.port {
    case "wait":
        fmt.println(eh.name, "/", msg.port, "=", msg.datum)

        d.init = time.tick_now()
        d. msg  = msg.datum.(string)
	zd.set_active (eh)

    case ".":
        data := d

        elapsed := time.tick_since(data.init)
        if elapsed < TIMEOUT {
	    // continue spinning
        } else {
            send(eh, "output", data.msg)
	    zd.set_idle (eh)
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

    fmt.println("--- Diagram: Yield ---")
    {
        main_container, ok := reg.get_component_instance(parts, "main")
        assert(ok, "Couldn't find main container... check the page name?")

        msg := make_message("yield", "Hello Yield!")
        main_container.handler(main_container, msg)
        print_output_list(main_container)
    }
    fmt.println("--- Diagram: Nested Yield ---")
    {
        main_container, ok := reg.get_component_instance(parts, "main")
        assert(ok, "Couldn't find main container... check the page name?")

        msg := make_message("nestedyield", "Hello Nested Yield!")
        main_container.handler(main_container, msg)
        print_output_list(main_container)
    }
}
