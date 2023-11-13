package kinopio2md

import "debug"

import "core:fmt"
import "core:log"
import "core:runtime"
import "core:strings"
import "core:slice"
import "core:os"
import "core:unicode/utf8"

import reg "registry0d"
import "process"
import "syntax"
import zd "0d"
import leaf "leaf0d"


main :: proc() {
    diagram_source_file, main_container_name := parse_command_line_args ()
    palette := initialize_component_palette ()
    run (&palette, main_container_name, diagram_source_file, start_function)
}




start_function :: proc (main_container : ^zd.Eh) {
    // p := zd.new_datum_string ("0dvsfbp/test109.json")
    // p := zd.new_datum_string ("0dvsfbp/test108.json")
    // p := zd.new_datum_string ("0dvsfbp/test107.json")
    // p := zd.new_datum_string ("0dvsfbp/test106.json")
    // p := zd.new_datum_string ("0dvsfbp/test105.json")
    // p := zd.new_datum_string ("0dvsfbp/test104.json")
    // p := zd.new_datum_string ("0dvsfbp/test103.json")
    // p := zd.new_datum_string ("0dvsfbp/test102.json")
    // p := zd.new_datum_string ("0dvsfbp/test101.json")
    // p := zd.new_datum_string ("kjson/test100.json")

    // chokes OhmJS?
    // p := zd.new_datum_string ("kjson/0dvsfbp.json") // full 0d-vs-fbp https://kinopio.club/0d-vs-fbp-pU5_-Ohrfh0d0VgKbYdws

    // DUP
    // // p := zd.new_datum_string ("play/test10.json") // full 0d-vs-fbp https://kinopio.club/0d-vs-fbp-pU5_-Ohrfh0d0VgKbYdws with spurious `; at end

    // p := zd.new_datum_string ("kjson/test9.json")
    // p := zd.new_datum_string ("kjson/test8.json")
    // p := zd.new_datum_string ("kjson/test7.json")
    // p := zd.new_datum_string ("kjson/test5.json") // test with dq and sq

    p := zd.new_datum_string ("kjson/softwareAtomsTest.json") // from Kinopio 'software atoms test' https://kinopio.club/software-atoms-test-FhzG4AniDsQj1ilz2N7FA

    // p := zd.new_datum_string ("kjson/test4.json")
    // p := zd.new_datum_string ("kjson/test2.json")
    // p := zd.new_datum_string ("kjson/test0.json")
    msg := zd.make_message("filename", p, zd.make_cause (main_container, nil) )
    main_container.handler(main_container, msg)
}


////////
project_specific_components :: proc (leaves: ^[dynamic]reg.Leaf_Template) {
    append(leaves, reg.Leaf_Template { name = "1then2", instantiate = leaf.deracer_instantiate })
    append(leaves, reg.Leaf_Template { name = "?", instantiate = leaf.probe_instantiate })
    append(leaves, reg.Leaf_Template { name = "trash", instantiate = leaf.trash_instantiate })

    append(leaves, reg.Leaf_Template { name = "Low Level Read Text File", instantiate = leaf.low_level_read_text_file_instantiate })
    append(leaves, reg.Leaf_Template { name = "Read Text From FD", instantiate = leaf.read_text_from_fd_instantiate })
    append(leaves, reg.Leaf_Template { name = "Open Text File", instantiate = leaf.open_text_file_instantiate })
    append(leaves, reg.Leaf_Template { name = "Ensure String Datum", instantiate = leaf.ensure_string_datum_instantiate })

    // for ohmjs
    append(leaves, reg.Leaf_Template { name = "HardCodedGrammar", instantiate = leaf.hard_coded_rwr_grammar_instantiate })
    append(leaves, reg.Leaf_Template { name = "HardCodedSemantics", instantiate = leaf.hard_coded_rwr_semantics_instantiate })
    append(leaves, reg.Leaf_Template { name = "HardCodedSupport", instantiate = leaf.hard_coded_rwr_support_instantiate })
    append(leaves, reg.Leaf_Template { name = "Bang", instantiate = leaf.bang_instantiate })
    append(leaves, reg.Leaf_Template { name = "stringconcat", instantiate = leaf.stringconcat_instantiate })
    append(leaves, reg.Leaf_Template { name = "OhmJS", instantiate = leaf.ohmjs_instantiate })

    // for RT front end
    append(leaves, reg.Leaf_Template { name = "'Word'", instantiate = leaf.word_instantiate })
    append(leaves, reg.Leaf_Template { name = "'rt/word.ohm'", instantiate = leaf.wordohm_instantiate })
    append(leaves, reg.Leaf_Template { name = "'rt/word.sem.js'", instantiate = leaf.wordjs_instantiate })

    append(leaves, reg.Leaf_Template { name = "'RWR'", instantiate = leaf.rwr_instantiate })
    append(leaves, reg.Leaf_Template { name = "'rwr/rwr.ohm'", instantiate = leaf.rwrohm_instantiate })
    append(leaves, reg.Leaf_Template { name = "'rwr/rwr.sem.js'", instantiate = leaf.rwrsemjs_instantiate })

    append(leaves, reg.Leaf_Template { name = "fakepipename", instantiate = leaf.fakepipename_instantiate })
    append(leaves, reg.Leaf_Template { name = "syncfilewrite", instantiate = leaf.syncfilewrite_instantiate })

    append(leaves, leaf.string_constant ("KinopioCards"))
    append(leaves, leaf.string_constant ("cards.ohm"))
    append(leaves, leaf.string_constant ("cards.rwr"))
    append(leaves, leaf.string_constant ("support.js"))
    append(leaves, leaf.string_constant ("content.pl"))

    append(leaves, leaf.string_constant ("Escapes"))
    append(leaves, leaf.string_constant ("rt/escapes.ohm"))
    append(leaves, leaf.string_constant ("rt/escapes.rwr"))
    append(leaves, leaf.string_constant ("rt/escapessupport.js"))
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

parse_command_line_args :: proc () -> {diagram_source_file, main_container_name: string} {
    diagram_source_file := slice.get(os.args, 1) or_else "vsh.drawio"
    main_container_name := slice.get(os.args, 2) or_else "main"
    
    if !os.exists(diagram_source_file) {
        fmt.println("Source diagram file", diagram_source_file, "does not exist.")
        os.exit(1)
    }
}

initialize_component_palette :: proc () -> {palette : Component_Registry} {
    leaves := make([dynamic]reg.Leaf_Instantiator)

    // set up shell leaves
    leaves := make([dynamic]reg.Leaf_Instantiator)

    leaf.collect_process_leaves(diagram_source_file, &leaves)

    // export native leaves
    reg.append_leaf (&leaves, reg.Leaf_Instantiator {
        name = "stdout",
        instantiate = leaf.stdout_instantiate,
    })

    project_specific_components (&leaves)

    palette := reg.make_component_registry(leaves[:], diagram_source_file)
}


main_with_logging :: proc() {
    // when debugging the 0D engine itself...
    diagram_source_file, main_container_name := parse_command_line_args ()
    palette := initialize_component_palette ()
    if need_logger () {
	context.logger = make_logger ()
    }
    run (&palette, main_container_name, diagram_source_file, start)
}



