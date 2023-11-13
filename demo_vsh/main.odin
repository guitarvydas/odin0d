package vsh

import "core:fmt"
import "core:time"
import zd "../0d"
import reg "../registry0d"

import "../debug"
import "core:log"
import "core:runtime"

main :: proc() {
    /* context.logger = log.create_console_logger( */
    /*     opt={.Level, .Time, .Terminal_Color}, */
    /* ) */

    // load arguments
    diagram_source_file := slice.get(os.args, 1) or_else "vsh.drawio"
    main_container_name := slice.get(os.args, 2) or_else "main"

    if !os.exists(diagram_source_file) {
        fmt.println("Source diagram file", diagram_source_file, "does not exist.")
        os.exit(1)
    }

    // set up shell leaves
    leaves := make([dynamic]reg.Leaf_Initializer)
    collect_process_leaves(diagram_source_file, &leaves)

    // export native leaves
    append(&leaves, reg.Leaf_Initializer {
        name = "stdout",
        init = leaf_stdout_init,
    })

    regstry := reg.make_component_registry(leaves[:], diagram_source_file)

    // get entrypoint container
    main_container, ok := reg.get_component_instance(regstry, main_container_name)
    fmt.assertf(
        ok,
        "Couldn't find main container with page name %s in file %s (check tab names, or disable compression?)\n",
        main_container_name,
        diagram_source_file,
    )

    // run!
    init_msg := zd.make_message("input", Bang{})
    main_container.handler(main_container, init_msg)

    fmt.println("--- Outputs ---")
    zd.print_output_list(main_container)
}
