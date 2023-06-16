/*

This example demonstrates taking a `.drawio` file and interpreting it at
runtime into a control flow configuration on top of the 0d runtime.

You can make edits to `example.drawio`, and re-run the program without
recompiling to observe changes.

See `README.md` for more information on the implemented reference diagram
syntax.

*/
package demo_drawio

import "core:mem"
import "core:fmt"
import "core:time"
import zd "../0d"
import reg "../registry0d"
import dt "../../datum"

leaf_echo_init :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("Echo (ID:%d)", counter)
    return zd.leaf_new (name_with_id, leaf_echo_proc, nil)
}

leaf_echo_proc :: proc(eh: ^zd.Eh, msg: zd.Message, data: any) {
    zd.send(eh, "output", msg.datum)
}

Sleep_Data :: struct {
    init: time.Tick,
    msg:  zd.Message,
}

convert_Sleep_Data_to_Datum :: proc (p : ^Sleep_Data) -> dt.Datum {
    size := size_of (Sleep_Data)			    
    r := new (dt.Datum)
    new_data, _ := mem.alloc (size)
    mem.copy (new_data, p, size)
    r.data = new_data
    r.len = size
    r.clone = dt.clone_datum
    r.reclaim = dt.reclaim_datum
    repr_Sleep_Data :: proc (self : dt.Datum) -> string {
        sd := convert_Datum_to_Sleep_Data (self)
        return fmt.aprintln (sd)
    }
    r. repr = repr_Sleep_Data
    r.reflection = "SleepDatum"
    return r^
}

convert_Datum_to_Sleep_Data :: proc (d : dt.Datum) -> Sleep_Data {
        pdata := transmute(^Sleep_Data)d.data
	return pdata^
}

leaf_sleep_init :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("Sleep (ID:%d)", counter)
    return zd.leaf_new (name_with_id, leaf_sleep_proc, nil)
}

leaf_sleep_proc :: proc(eh: ^zd.Eh, msg: zd.Message, data: any) {
    TIMEOUT :: 1 * time.Second

    switch msg.port {
    case "wait":
        sdata := Sleep_Data {
            init = time.tick_now(),
            msg  = msg
        }

	data := convert_Sleep_Data_to_Datum (&sdata)

        zd.yield(eh, "sleep", data)
    case "sleep":
        data := convert_Datum_to_Sleep_Data (msg.datum)
        elapsed := time.tick_since(data.init)
        if elapsed < TIMEOUT {
            zd.yield(eh, "sleep", msg.datum) // zd.yield will deep-clone clone msg.dagum
        } else {
            zd.send(eh, "output", data.msg.datum)
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

        msg := zd.make_message_from_string ("seq", "Hello Sequential!")
        main_container.handler(main_container, msg, nil)
        zd.print_output_list(main_container)
    }

    fmt.println("--- Diagram: Parallel Routing ---")
    {
        main_container, ok := reg.get_component_instance(parts, "main")
        assert(ok, "Couldn't find main container... check the page name?")

        msg := zd.make_message_from_string ("par", "Hello Parallel!")
        main_container.handler(main_container, msg, nil)
        zd.print_output_list(main_container)
    }

    fmt.println("--- Diagram: Yield ---")
    {
        main_container, ok := reg.get_component_instance(parts, "main")
        assert(ok, "Couldn't find main container... check the page name?")

        msg := zd.make_message_from_string ("yield", "Hello Yield!")
        main_container.handler(main_container, msg, nil)
        zd.print_output_list(main_container)
    }
}
