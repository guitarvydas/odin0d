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

leaf_stdout_instantiate :: proc(name: string) -> ^zd.Eh {
    return zd.make_leaf(name, leaf_stdout_proc)
}

leaf_stdout_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    fmt.printf("%#v", msg.datum)
}

leaf_process_instantiate :: proc(name: string) -> ^zd.Eh {
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

        // breaks bootstrap error check zd.send(eh, "done", Bang{})

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

collect_process_leaves :: proc(path: string, leaves: ^[dynamic]reg.Leaf_Instantiator) {
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
                leaf_instantiate := reg.Leaf_Instantiator {
                    name = child.name,
                    init = leaf_process_instantiate,
                }
                append(leaves, leaf_instantiate)
            }
        }
    }
}

main :: proc() {

    if user_start_logger () {
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
    collect_process_leaves(diagram_source_file, &leaves)

    // export native leaves
    append(&leaves, reg.Leaf_Instantiator {
        name = "stdout",
        init = leaf_stdout_instantiate,
    })



    user_components (&leaves)

    regstry := reg.make_component_registry(leaves[:], diagram_source_file)

    // get entrypoint container
    main_container, ok := reg.get_component_instance(regstry, main_container_name)
    fmt.assertf(
        ok,
        "Couldn't find main container with page name %s in file %s (check tab names, or disable compression?)\n",
        main_container_name,
        diagram_source_file,
    )

    user_run (main_container)

    fmt.println("--- Outputs ---")
    zd.print_output_list(main_container)
}



leaf_hard_coded_ps_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("ps (ID:%d)", counter)
    return zd.make_leaf(name_with_id, leaf_hard_coded_ps_proc)
}

leaf_hard_coded_ps_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    captured_output := process.run_command ("ps", nil)
    zd.send(eh, "stdout", captured_output)
}

leaf_hard_coded_grepvsh_instantiate :: proc(name: string) -> ^zd.Eh {
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

leaf_hard_coded_wcl_instantiate :: proc(name: string) -> ^zd.Eh {
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

Command_Instance_Data :: struct {
    buffer : string
}

leaf_command_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("command (ID:%d)", counter)
    inst := new (Command_Instance_Data)
    return zd.make_leaf_with_data (name_with_id, inst, leaf_command_proc)
}

leaf_command_proc :: proc(eh: ^zd.Eh, msg: zd.Message, inst: ^Command_Instance_Data) {
    switch msg.port {
    case "command":
        inst.buffer = msg.datum.(string)
    case "stdin":
        received_input := msg.datum.(string)
        captured_output := process.run_command (inst.buffer, received_input)
        zd.send(eh, "stdout", captured_output)
    case:
        fmt.assertf (false, "!!! ERROR: command got an illegal message port %v", msg.port)
    }
}

leaf_literalwcl_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("literalwcl (ID:%d)", counter)
    return zd.make_leaf(name_with_id, leaf_literalwcl_proc)
}

leaf_literalwcl_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    zd.send(eh, "literal", "wc -l")
}


leaf_literalgrepvsh_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("literalgrepvsh (ID:%d)", counter)
    return zd.make_leaf(name_with_id, leaf_literalgrepvsh_proc)
}

leaf_literalgrepvsh_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    zd.send(eh, "literal", "grep vsh")
}



////

TwoAnys :: struct {
    first : zd.Message,
    second : zd.Message
}


Deracer_States :: enum { idle, waitingForFirst, waitingForSecond }

Deracer_Instance_Data :: struct {
    state : Deracer_States,
    buffer : TwoAnys
}

reclaim_Buffers_from_heap :: proc (inst : ^Deracer_Instance_Data) {
    zd.destroy_message (inst.buffer.first)
    zd.destroy_message (inst.buffer.second)
}

leaf_deracer_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("deracer (ID:%d)", counter)
    inst := new (Deracer_Instance_Data) // allocate in the heap
    eh := zd.make_leaf_with_data (name_with_id, inst, leaf_deracer_proc)
    inst.state = .idle
    return eh
}

send_first_then_second :: proc (eh : ^zd.Eh, inst: ^Deracer_Instance_Data) {
    zd.send(eh, "1", inst.buffer.first.datum)
    zd.send(eh, "2", inst.buffer.second.datum)
    reclaim_Buffers_from_heap (inst)
}

leaf_deracer_proc :: proc(eh: ^zd.Eh,  msg: zd.Message, inst: ^Deracer_Instance_Data) {
    switch (inst.state) {
    case .idle:
        switch msg.port {
        case "1":
            inst.buffer.first = msg
            inst.state = .waitingForSecond
        case "2":
            inst.buffer.second = msg
            inst.state = .waitingForFirst
        case:
            fmt.assertf (false, "bad msg.port A for deracer %v\n", msg.port)
        }
    case .waitingForFirst:
        switch msg.port {
        case "1":
            inst.buffer.first = msg
            send_first_then_second (eh, inst)
            inst.state = .idle
        case:
            fmt.assertf (false, "bad msg.port B for deracer %v\n", msg.port)
        }
    case .waitingForSecond:
        switch msg.port {
        case "2":
            inst.buffer.second = msg
            send_first_then_second (eh, inst)
            inst.state = .idle
        case:
            fmt.assertf (false, "bad msg.port C for deracer %v\n", msg.port)
        }
    case:
        fmt.assertf (false, "bad state for deracer %v\n", eh.state)
    }
}

/////////

leaf_probe_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("?%d", counter)
    return zd.make_leaf(name_with_id, leaf_probe_proc)
}

leaf_probe_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    fmt.println (eh.name, msg.datum)
}

leaf_literalvsh_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("literalvsh (ID:%d)", counter)
    return zd.make_leaf(name_with_id, leaf_literalvsh_proc)
}

leaf_literalvsh_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    zd.send(eh, "literal", "vsh")
}

leaf_literalgrep_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("literalgrep (ID:%d)", counter)
    return zd.make_leaf(name_with_id, leaf_literalgrep_proc)
}

leaf_literalgrep_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    zd.send(eh, "literal", "grep ")
}

///

StringConcat_Instance_Data :: struct {
    buffer : string
}

leaf_stringconcat_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("stringconcat (ID:%d)", counter)
    inst := new (StringConcat_Instance_Data)
    return zd.make_leaf(name_with_id, inst, leaf_stringconcat_proc)
}

leaf_stringconcat_proc :: proc(eh: ^zd.Eh, msg: zd.Message, inst: ^StringConcat_Instance_Data) {
    switch msg.port {
    case "1":
	inst.buffer = strings.clone (msg.datum.(string))
    case "2":
	concatenated_string := fmt.aprintf ("%s%s", inst.buffer, msg.datum.(string))
	zd.send(eh, "str", concatenated_string)
    }
}

