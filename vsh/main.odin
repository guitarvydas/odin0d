package vsh

import "core:fmt"
import "core:log"
import "core:strings"
import "core:slice"
import "core:os"
import "core:unicode/utf8"

import reg "../registry0d"
import "../process"
import "../syntax"
import zd "../0d"
import user "../user0d"
import leaf "../leaf0d"

main :: proc() {

    if user.start_logger () {
	fmt.println ("*** starting logger ***")
	context.logger = log.create_console_logger(
            opt={.Level, .Time, .Terminal_Color},
	)
    }

    // load arguments
    diagram_source_file := slice.get(os.args, 1) or_else "vsh.drawio"
    main_container_name := slice.get(os.args, 2) or_else "main"

    if !os.exists(diagram_source_file) {
        fmt.println("Source diagram file", diagram_source_file, "does not exist.")
        os.exit(1)
    }

    // set up shell leaves
    leaves := make([dynamic]reg.Leaf_Instantiator)
    leaf.collect_process_leaves(diagram_source_file, &leaves)

    // export native leaves
    append(&leaves, reg.Leaf_Instantiator {
        name = "stdout",
        init = leaf.stdout_instantiate,
    })



    user.components (&leaves)

    regstry := reg.make_component_registry(leaves[:], diagram_source_file)

    reg.dump_registry (regstry)
    
    // get entrypoint container
    main_container, ok := reg.get_component_instance(regstry, main_container_name)
    fmt.assertf(
        ok,
        "Couldn't find main container with page name %s in file %s (check tab names, or disable compression?)\n",
        main_container_name,
        diagram_source_file,
    )

    user.run (main_container)

    fmt.println("--- Outputs ---")
    zd.print_output_list(main_container)
}

