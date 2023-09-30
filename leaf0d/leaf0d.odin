package leaf0d

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

stdout_instantiate :: proc(name: string) -> ^zd.Eh {
    return zd.make_leaf(name, stdout_proc)
}

stdout_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    fmt.printf("%#v", msg.datum)
}

process_instantiate :: proc(name: string) -> ^zd.Eh {
    command_string := strings.clone(strings.trim_left(name, "$ "))
    command_string_ptr := new_clone(command_string)
    return zd.make_leaf(name, command_string_ptr, process_proc)
}

process_proc :: proc(eh: ^zd.Eh, msg: zd.Message, command: ^string) {

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
            case zd.Bang:
                // OK, no input, just run it
            case:
                log.errorf("%s: Shell leaf input can handle string, bytes, or bang (got: %v)", eh.name, value.id)
            }
            os.close(handle.input)
            process.process_wait(handle)
        }

        // breaks bootstrap error check, thus, removed line: zd.send(eh, "done", Bang{})

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
                    init = process_instantiate,
                }
                append(leaves, leaf_instantiate)
            }
        }
    }
}


hard_coded_ps_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("ps (ID:%d)", counter)
    return zd.make_leaf(name_with_id, hard_coded_ps_proc)
}

hard_coded_ps_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    captured_output := process.run_command ("ps", nil)
    zd.send(eh, "stdout", captured_output)
}

hard_coded_grepvsh_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("grepvsh (ID:%d)", counter)
    return zd.make_leaf(name_with_id, hard_coded_grepvsh_proc)
}

hard_coded_grepvsh_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    received_input := msg.datum.(string)
    captured_output := process.run_command ("grep vsh", received_input)
    zd.send(eh, "stdout", captured_output)
}

hard_coded_wcl_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("wcl (ID:%d)", counter)
    return zd.make_leaf(name_with_id, hard_coded_wcl_proc)
}

hard_coded_wcl_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    received_input := msg.datum.(string)
    captured_output := process.run_command ("wc -l", received_input)
    zd.send(eh, "stdout", captured_output)
}

////

Command_Instance_Data :: struct {
    buffer : string
}

command_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("command (ID:%d)", counter)
    inst := new (Command_Instance_Data)
    return zd.make_leaf_with_data (name_with_id, inst, command_proc)
}

command_proc :: proc(eh: ^zd.Eh, msg: zd.Message, inst: ^Command_Instance_Data) {
    switch msg.port {
    case "command":
        inst.buffer = msg.datum.(string)
        received_input := msg.datum.(string)
        captured_output := process.run_command (inst.buffer, received_input)
        zd.send(eh, "stdout", captured_output)
    case:
        fmt.assertf (false, "!!! ERROR: command got an illegal message port %v", msg.port)
    }
}

icommand_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("icommand (ID:%d)", counter)
    inst := new (Command_Instance_Data)
    return zd.make_leaf_with_data (name_with_id, inst, icommand_proc)
}

icommand_proc :: proc(eh: ^zd.Eh, msg: zd.Message, inst: ^Command_Instance_Data) {
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

literalwcl_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("literalwcl (ID:%d)", counter)
    return zd.make_leaf(name_with_id, literalwcl_proc)
}

literalwcl_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    zd.send(eh, "literal", "wc -l")
}


literalgrepvsh_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("literalgrepvsh (ID:%d)", counter)
    return zd.make_leaf(name_with_id, literalgrepvsh_proc)
}

literalgrepvsh_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    zd.send(eh, "literal", "grep vsh")
}

literalpsgrepwcl_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("literalpsgrepwcl (ID:%d)", counter)
    return zd.make_leaf(name_with_id, literalpsgrepwcl_proc)
}

literalpsgrepwcl_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    zd.send(eh, "literal", "ps | grep vsh | wc -l")
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

deracer_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("deracer (ID:%d)", counter)
    inst := new (Deracer_Instance_Data) // allocate in the heap
    eh := zd.make_leaf_with_data (name_with_id, inst, deracer_proc)
    inst.state = .idle
    return eh
}

send_first_then_second :: proc (eh : ^zd.Eh, inst: ^Deracer_Instance_Data) {
    zd.send(eh, "1", inst.buffer.first.datum)
    zd.send(eh, "2", inst.buffer.second.datum)
    reclaim_Buffers_from_heap (inst)
}

deracer_proc :: proc(eh: ^zd.Eh,  msg: zd.Message, inst: ^Deracer_Instance_Data) {
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

probe_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("?%d", counter)
    return zd.make_leaf(name_with_id, probe_proc)
}

probe_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    fmt.println (eh.name, msg.datum)
}

literalvsh_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("literalvsh (ID:%d)", counter)
    return zd.make_leaf(name_with_id, literalvsh_proc)
}

literalvsh_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    zd.send(eh, "literal", "vsh")
}

literalgrep_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("literalgrep (ID:%d)", counter)
    return zd.make_leaf(name_with_id, literalgrep_proc)
}

literalgrep_proc :: proc(eh: ^zd.Eh, msg: zd.Message) {
    zd.send(eh, "literal", "grep ")
}

///

StringConcat_Instance_Data :: struct {
    buffer : string
}

stringconcat_instantiate :: proc(name: string) -> ^zd.Eh {
    @(static) counter := 0
    counter += 1

    name_with_id := fmt.aprintf("stringconcat (ID:%d)", counter)
    inst := new (StringConcat_Instance_Data)
    return zd.make_leaf(name_with_id, inst, stringconcat_proc)
}

stringconcat_proc :: proc(eh: ^zd.Eh, msg: zd.Message, inst: ^StringConcat_Instance_Data) {
    switch msg.port {
    case "1":
	inst.buffer = strings.clone (msg.datum.(string))
    case "2":
	concatenated_string := fmt.aprintf ("%s%s", inst.buffer, msg.datum.(string))
	zd.send(eh, "str", concatenated_string)
    case:
        fmt.assertf (false, "bad msg.port for stringconcat: %v\n", msg.port)
    }
}

