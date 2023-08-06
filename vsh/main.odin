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

Bang :: struct {}

leaf_stdout_init :: proc(name: string) -> ^zd.Eh {
    return zd.make_leaf(name, leaf_stdout_proc)
}

leaf_stdout_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    fmt.printf("%#v", msg.datum)
}

leaf_process_init :: proc(name: string) -> ^zd.Eh {
    command_string := strings.clone(strings.trim_left(name, "$ "))
    command_string_ptr := new_clone(command_string)
    return zd.make_leaf(name, command_string_ptr, leaf_process_proc)
}

leaf_process_proc :: proc(eh: ^zd.Eh, msg: zd.Message, command: ^string) {

    utf8_string :: proc(bytes: []byte) -> (s: string, ok: bool) {
        s = string(bytes)
        ok = utf8.valid_string(s)
        return
    }
    
    send_output :: proc(eh: ^zd.Eh, port: string, output: []byte) {
        if len(output) > 0 {
            str, ok := utf8_string(output)
            if ok {
                zd.send(eh, port, str)
            } else {
                zd.send(eh, port, output)
            }
        }
    }

    switch msg.port {
    case "stdin":
        handle := process.process_start(command^)
        defer process.process_destroy_handle(handle)

        // write input, wait for finish
        {
            switch value in msg.datum {
            case string:
                bytes := transmute([]byte)value
                os.write(handle.input, bytes)
            case []byte:
                os.write(handle.input, value)
            case Bang:
                // OK, no input, just run it
            case:
                log.errorf("%s: Shell leaf input can handle string, bytes, or bang (got: %v)", eh.name, value.id)
            }
            os.close(handle.input)
            process.process_wait(handle)
        }

        zd.send(eh, "done", Bang{})

        // stdout handling
        {
            stdout, ok := process.process_read_handle(handle.output)
            if ok {
                send_output(eh, "stdout", stdout)
            }
        }

        // stderr handling
        {
            stderr, ok := process.process_read_handle(handle.error)
            if ok {
                send_output(eh, "stderr", stderr)
            }

            if len(stderr) > 0 {
                str := string(stderr)
                str = strings.trim_right_space(str)
                log.error(str)
            }
        }
    }
}

collect_process_leaves :: proc(path: string, leaves: ^[dynamic]reg.Leaf_Initializer) {
    ref_is_container :: proc(decls: []syntax.Container_Decl, name: string) -> bool {
        for d in decls {
            if d.name == name {
                return true
            }
        }
        return false
    }

    decls, err := syntax.parse_drawio_mxgraph(path)
    assert(err == nil)
    defer delete(decls)

    // TODO(z64): while harmless, this doesn't ignore duplicate process decls yet.

    for decl in decls {
        for child in decl.children {
            if ref_is_container(decls[:], child.name) {
                continue
            }

            if strings.has_prefix(child.name, "$") {
                leaf_init := reg.Leaf_Initializer {
                    name = child.name,
                    init = leaf_process_init,
                }
                append(leaves, leaf_init)
            }
        }
    }
}

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

    append(&leaves, reg.Leaf_Initializer {
        name = "hard_coded_ps",
        init = leaf_hard_coded_ps_init,
    })

    append(&leaves, reg.Leaf_Initializer {
        name = "hard_coded_grepvsh",
        init = leaf_hard_coded_grepvsh_init,
    })

    append(&leaves, reg.Leaf_Initializer {
        name = "hard_coded_wcl",
        init = leaf_hard_coded_wcl_init,
    })

    append(&leaves, reg.Leaf_Initializer {
        name = "command",
        init = leaf_command_init,
    })

    append(&leaves, reg.Leaf_Initializer {
        name = "literalwcl",
        init = leaf_literalwcl_init,
    })

    append(&leaves, reg.Leaf_Initializer {
        name = "deracer",
        init = leaf_deracer_init,
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



leaf_hard_coded_ps_init :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("ps (ID:%d)", counter)
    return zd.make_leaf(name_with_id, leaf_hard_coded_ps_proc)
}

leaf_hard_coded_ps_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    captured_output := process.run_command ("ps", nil)
    zd.send(eh, "stdout", captured_output)
}

leaf_hard_coded_grepvsh_init :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("grepvsh (ID:%d)", counter)
    return zd.make_leaf(name_with_id, leaf_hard_coded_grepvsh_proc)
}

leaf_hard_coded_grepvsh_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    received_input := msg.datum.(string)
    captured_output := process.run_command ("grep vsh", received_input)
    zd.send(eh, "stdout", captured_output)
}

leaf_hard_coded_wcl_init :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("wcl (ID:%d)", counter)
    return zd.make_leaf(name_with_id, leaf_hard_coded_wcl_proc)
}

leaf_hard_coded_wcl_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    received_input := msg.datum.(string)
    captured_output := process.run_command ("wc -l", received_input)
    zd.send(eh, "stdout", captured_output)
}

////

leaf_command_init :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("command (ID:%d)", counter)
    return zd.make_leaf(name_with_id, leaf_command_proc)
}

leaf_command_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    fmt.println ("command active: ", eh.active, " ; in state: ", eh.state, " ; gets: ", msg)
    switch msg.port {
    case "command":
        // nothing yet
        zd.set_active (eh)
        fmt.println ("command is: %v", msg.datum.(string))
    case ".":
    case "stdin":
        received_input := msg.datum.(string)
        captured_output := process.run_command ("wc -l", received_input)
        zd.send(eh, "stdout", captured_output)
	zd.set_idle (eh)
    case:
        fmt.println ("!!! ERROR: command got an illegal message port %v", msg.port)
        assert (false)
    }
}

leaf_literalwcl_init :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("literalwcl (ID:%d)", counter)
    return zd.make_leaf(name_with_id, leaf_literalwcl_proc)
}

leaf_literalwcl_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    fmt.println ("literalwcl active: ", eh.active, " ; in state: ", eh.state, " ; gets: ", msg)
    zd.send(eh, "stdout", "wc -l")
}


////

TwoAnys :: struct {
    first : any,
    second : any
}


Deracer_States :: enum { idle, waitingForFirst, waitingForSecond }

reclaim_TwoAnys_from_heap :: proc (ta: ^TwoAnys) {
    free (ta)
}

leaf_deracer_init :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("deracer (ID:%d)", counter)
    ta := new (TwoAnys) // allocate in the heap
    eh := zd.make_leaf_with_data (name_with_id, ta, leaf_deracer_proc)
    zd.set_state (eh, Deracer_States.idle)
    return eh
}

send_first_then_second :: proc (eh : ^zd.Eh, ta: ^TwoAnys) {
    fmt.println ("sfts sending ", ta.first)
    zd.send(eh, "first", ta.first)
    fmt.println ("sfts sending ", ta.second)
    zd.send(eh, "second", ta.second)
    fmt.println ("sfts reclaiming")
    reclaim_TwoAnys_from_heap (ta)
}

leaf_deracer_proc :: proc(eh: ^zd.Eh,  msg: zd.Message, ta: ^TwoAnys) {
    fmt.println ("deracer active: ", eh.active, " ; in state: ", transmute(Deracer_States)eh.state, " ; gets: ", msg)
    switch (transmute(Deracer_States)eh.state) {
    case Deracer_States.idle:
        switch msg.port {
        case "first":
            ta.first = msg.datum.(string)
            zd.set_state (eh, Deracer_States.waitingForSecond)
        case "second":
            ta.second = msg.datum.(string)
            zd.set_state (eh, Deracer_States.waitingForFirst)
        case:
            fmt.printf ("bad msg.port A for deracer %v\n", msg.port)
            assert (false)
        }
    case Deracer_States.waitingForFirst:
        switch msg.port {
        case "first":
            ta.first = msg.datum.(string)
            send_first_then_second (eh, ta)
            zd.set_state (eh, Deracer_States.idle)
        case:
            fmt.printf ("bad msg.port B for deracer %v\n", msg.port)
            assert (false)
        }
    case Deracer_States.waitingForSecond:
        switch msg.port {
        case "second":
            ta.second = msg.datum.(string)
            send_first_then_second (eh, ta)
            zd.set_state (eh, Deracer_States.idle)
        case:
            fmt.printf ("bad msg.port C for deracer %v\n", msg.port)
            assert (false)
        }
    case:
        fmt.printf ("bad state for deracer %v\n", eh.state)
        assert (false)
    }
}
