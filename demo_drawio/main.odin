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

import "../debug"
import "core:log"
import "core:runtime"

Eh                :: zd.Eh
Message           :: zd.Message
make_container    :: zd.make_container
make_message      :: zd.make_message
make_leaf         :: zd.make_leaf
send              :: zd.send
print_output_list :: zd.print_output_list

gensym :: proc (s : string) -> string {
    @(static) counter := 0
    counter += 1
    name_with_id := fmt.aprintf("%s◦%d", s, counter)
    return name_with_id
}

makeleaf :: proc (name: string, handler: #type proc(^Eh, ^Message)) -> ^Eh {
    return make_leaf(name_prefix="", name=name, owner=nil, instance_data=nil, handler=echo_handler)
}

echo_instantiate :: proc(name_prefix: string, name: string, owner : ^zd.Eh) -> ^zd.Eh {
    name_with_id := gensym("?")
    return zd.make_leaf (name_prefix, name_with_id, owner, nil, echo_handler)
}

echo_handler :: proc(eh: ^Eh, message: ^Message) {
    send(eh=eh, port="output", datum=message.datum, causingMessage=nil)
}


///
SleepInfo :: struct {
    counter : int,
    saved_message : ^Message
}

SLEEPDELAY := 1000000

sleep_instantiate :: proc(name_prefix: string, name: string, owner : ^zd.Eh) -> ^zd.Eh {
    info := new (SleepInfo)
    info.counter = 0
    name_with_id := gensym("?")
    eh :=  zd.make_leaf (name_prefix, name_with_id, owner, info^, sleep_handler)
    return eh
}

sleep_handler :: proc(eh: ^Eh, message: ^Message) {
    first_time :: proc (m: ^Message) -> bool {
	return ! zd.is_tick (m)
    }
    info := &eh.instance_data.(SleepInfo)
    if first_time (message) {
	info.saved_message = message
	zd.set_active (eh) // tell engine to keep running this component with 'ticks'
    }
    count := info.counter
    count += 1
    if count >= SLEEPDELAY {
	zd.set_idle (eh) // tell engine that we're finally done
	zd.forward (eh=eh, port="output", msg=info.saved_message)
	count = 0
    }
   info.counter = count
}

///

main :: proc() {
    leaves: []reg.Leaf_Template = {
        {
            name = "Echo",
            instantiate = echo_instantiate,
        },
        {
            name = "Sleep",
            instantiate = sleep_instantiate,
        },
    }

    parts := reg.make_component_registry(leaves, "example.drawio")

    fmt.println("--- Diagram: Sequential Routing ---")
    {
        main_container, ok := reg.get_component_instance(&parts, "", "main", nil)
        assert(ok, "Couldn't find main container... check the page name?")

	// uncomment this next section to enable the logger
	// (for debugging, for log_hierarchy, etc)
	/* 	// need to enable logger to see output from log_hierarchy () */
	/* log_level := zd.log_handlers // set this to only track handlers in Components */
	/* //log_level := zd.log_all // set this to track everything, equivalen to runtime.Logger_Level.Debug */
	/* // log_level := runtime.Logger_Level.Info */
	/* fmt.printf ("\n*** starting logger level %v ***\n", log_level) */
	/* context.logger = log.create_console_logger( */
	/* 	lowest=cast(runtime.Logger_Level)log_level, */
	/*     opt={.Level, .Time, .Terminal_Color}, */
	/* ) */

	// This is pretty boring for this simple example.
	// When you begin building projects that use Containers,
	// this will print (if logging enabled, above) a list
	// of components with unique IDs in Lisp format.  Copy/paste the result into a Lisp pretty
	// printer (I use emacs lisp-mode) to see the hierarchy in indented format).
	debug.log_hierarchy (main_container)

        msg := make_message("seq", zd.new_datum_string ("Hello Sequential!"), nil)
        main_container.handler(main_container, msg)
        print_output_list(main_container)
    }

    fmt.println("--- Diagram: Parallel Routing ---")
    {
        main_container, ok := reg.get_component_instance(&parts, "", "main", nil)
        assert(ok, "Couldn't find main container... check the page name?")

	debug.log_hierarchy (main_container)
        msg := make_message("par", zd.new_datum_string ("Hello Parallel!"), nil)
        main_container.handler(main_container, msg)
        print_output_list(main_container)
    }

    fmt.println("--- Diagram: Delay ---")
    {
        main_container, ok := reg.get_component_instance(&parts, "", "main", nil)
        assert(ok, "Couldn't find main container... check the page name?")

	debug.log_hierarchy (main_container)
        msg := make_message("delayed", zd.new_datum_string ("Hello Delayed Parallel!"), nil)
        main_container.handler(main_container, msg)
        print_output_list(main_container)
    }
}
