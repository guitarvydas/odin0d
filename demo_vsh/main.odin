package kinopio2md

import "core:fmt"
import "core:log"
import "core:runtime"
import "core:strings"
import "core:slice"
import "core:os"
import "core:unicode/utf8"

import reg "../registry0d"
import "../process"
import "../syntax"
import zd "../0d"
import leaf "../leaf0d"
import "../debug"


main :: proc() {
    diagram_source_file, main_container_name := parse_command_line_args ()
    palette := initialize_component_palette (diagram_source_file)
    run (&palette, main_container_name, diagram_source_file, start_function)
}




start_function :: proc (main_container : ^zd.Eh) {
    b := zd.new_datum_bang ()
    msg := zd.make_message("input", b, zd.make_cause (main_container, nil) )
    main_container.handler(main_container, msg)
}


////////
project_specific_components :: proc (leaves: ^[dynamic]reg.Leaf_Template) {
    append(leaves, reg.Leaf_Template { name = "?", instantiate = leaf.probe_instantiate })
    append(leaves, reg.Leaf_Template { name = "trash", instantiate = leaf.trash_instantiate })
}


run :: proc (r : ^reg.Component_Registry, main_container_name : string, diagram_source_file : string, injectfn : #type proc (^zd.Eh)) {
    pregistry := r
    // get entrypoint container
    main_container, ok := reg.get_component_instance(pregistry, "", main_container_name, owner=nil)
    fmt.assertf(
        ok,
        "Couldn't find main container with page name %s in file %s (check tab names, or disable compression?)\n",
        main_container_name,
        diagram_source_file,
    )
    // dump_hierarchy (main_container)
    injectfn (main_container)
    // dump_outputs (main_container)
    // dump_stats (pregstry)
    print_error (main_container)
    print_output (main_container)
    fmt.println("\n\n--- done ---")
}


print_output :: proc (main_container : ^zd.Eh) {
    fmt.println("\n\n--- RESULT ---")
    zd.print_specific_output (main_container, "output")
}
print_error :: proc (main_container : ^zd.Eh) {
    fmt.println("\n\n--- ERRORS (if any) ---")
    zd.print_specific_output (main_container, "error")
}



// debugging helpers

dump_hierarchy :: proc (main_container : ^zd.Eh) {
    fmt.println("\n\n--- Hierarchy ---")
    debug.log_hierarchy (main_container)
}

dump_outputs :: proc (main_container : ^zd.Eh) {
    fmt.println("\n\n--- Outputs ---")
    zd.print_output_list(main_container)
}

dump_stats :: proc (pregstry : ^reg.Component_Registry) {
    reg.print_stats (pregstry)
}


need_logging :: proc () -> bool {
    // don't use logging unless you are debugging the 0d engine
    // for user-level debugging, use '?' parts (probes) on the diagram
    return false
}

make_logger :: proc () -> log.Logger {
    // set this to only track handlers in Components
    log_level := zd.log_handlers // set this to only track handlers in Components
    //log_level := zd.log_all // set this to track everything, equivalent to runtime.Logger_Level.Debug
    // log_level := runtime.Logger_Level.Info
    fmt.printf ("\n*** starting logger level %v ***\n", log_level)
    return log.create_console_logger(
	lowest=cast(runtime.Logger_Level)log_level,
        opt={.Level, .Time, .Terminal_Color},
    )
}

parse_command_line_args :: proc () -> (diagram_source_file, main_container_name: string) {
    diagram_source_file = slice.get(os.args, 1) or_else "vsh.drawio"
    main_container_name = slice.get(os.args, 2) or_else "main"
    
    if !os.exists(diagram_source_file) {
        fmt.println("Source diagram file", diagram_source_file, "does not exist.")
        os.exit(1)
    }
    return diagram_source_file, main_container_name
}

initialize_component_palette :: proc (diagram_source_file: string) -> (palette: reg.Component_Registry) {
    leaves := make([dynamic]reg.Leaf_Instantiator)

    // set up shell leaves
    leaf.collect_process_leaves(diagram_source_file, &leaves)

    // export native leaves
    reg.append_leaf (&leaves, reg.Leaf_Instantiator {
        name = "stdout",
        instantiate = leaf.stdout_instantiate,
    })

    project_specific_components (&leaves)

    palette = reg.make_component_registry(leaves[:], diagram_source_file)
    return palette
}


main_with_logging :: proc() {
    // when debugging the 0D engine itself...
    diagram_source_file, main_container_name := parse_command_line_args ()
    palette := initialize_component_palette (diagram_source_file)
    if need_logging () {
	context.logger = make_logger ()
    }
    run (&palette, main_container_name, diagram_source_file, start_function)
}



