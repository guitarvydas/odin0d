package leaf0d

import "core:fmt"
import "core:runtime"
import "core:log"
import "core:strings"
import "core:slice"
import "core:os"
import "core:unicode/utf8"

import reg "../registry0d"
import "../process"
import "../syntax"
import zd "../0d"

gensym :: proc (s : string) -> string {
    @(static) counter := 0
    counter += 1
    name_with_id := fmt.aprintf("%s◦%d", s, counter)
    return name_with_id
}


stdout_instantiate :: proc(name_prefix: string,name: string, owner : ^zd.Eh) -> ^zd.Eh {
    return zd.make_leaf(name_prefix, name, owner, nil, stdout_handle)
}

stdout_handle :: proc(eh: ^zd.Eh, msg: ^zd.Message) {
    fmt.printf("%#v", msg.datum)
}

process_instantiate :: proc(name_prefix: string, name: string, owner : ^zd.Eh) -> ^zd.Eh {
    command_string := strings.clone(strings.trim_left(name, "$ "))
    command_string_ptr := new_clone(command_string)
    return zd.make_leaf(name_prefix, name, owner, command_string_ptr^, process_handle)
}

process_handle :: proc(eh: ^zd.Eh, msg: ^zd.Message) {
    
    utf8_string :: proc(bytes: []byte) -> (s: string, ok: bool) {
        s = string(bytes)
        ok = utf8.valid_string(s)
        return
    }
    
    send_output :: proc(eh: ^zd.Eh, port: string, output: []byte, causingMsg: ^zd.Message) {
        if len(output) > 0 {
            zd.send (eh, port, zd.new_datum_bytes (output), causingMsg)
        }
    }

    switch msg.port {
    case "input":
        handle := process.process_start(eh.instance_data.(string))
        defer process.process_destroy_handle(handle)

        // write input, wait for finish
        {
            switch value in msg.datum.data {
            case string:
                bytes := transmute([]byte)value
                os.write(handle.input, bytes)
            case []byte:
                os.write(handle.input, value)
            case bool: //zd.Bang:
                // OK, no input, just run it
	    case:
                log.errorf("%s: Shell leaf input can handle string, bytes, or bang (got: %v)", eh.name, value.id)
            }
            os.close(handle.input)
            process.process_wait(handle)
        }

        // breaks bootstrap error check, thus, removed line: zd.send_string (eh, "done", Bang{})

        // stdout handling
        {
            stdout, stdout_ok := process.process_read_handle(handle.output)

            // stderr handling
            stderr_untrimmed, stderr_ok := process.process_read_handle(handle.error)
	    stderr : string
            if stderr_ok {
		stderr = strings.trim_right_space(cast(string)stderr_untrimmed)
            }
	    if stdout_ok && stderr_ok {
		// fire only one output port
		// on error, send both, stdout and stderr to the error port
		if len (stderr) > 0 {
                    send_output (eh, "error", stdout, msg)
		    zd.send_string(eh, "error", stderr, msg)
		} else {
                    zd.send_string (eh, "output", transmute(string)stdout, msg)
		}
	    } else {
		// panic - we should never fail to collect stdout and stderr
		// if we come here, then something is deeply wrong with this code
		fmt.assertf (false, "PANIC: failed to retrieve outputs stdout_ok = %v stderr_ok = %v\n", stdout_ok, stderr_ok)
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
                    instantiate = process_instantiate,
                }
                append(leaves, leaf_instantiate)
            }
        }
    }
}

////

Command_Instance_Data :: struct {
    buffer : string
}

command_instantiate :: proc(name_prefix: string, name: string, owner : ^zd.Eh) -> ^zd.Eh {
    name_with_id := gensym("command")
    instp := new (Command_Instance_Data)
    return zd.make_leaf (name_prefix, name_with_id, owner, instp^, command_handle)
}

command_handle :: proc(eh: ^zd.Eh, msg: ^zd.Message) {
    inst := eh.instance_data.(Command_Instance_Data)
    switch msg.port {
    case "command":
        inst.buffer = msg.datum.asString (msg.datum)
        received_input := msg.datum.asString (msg.datum)
        captured_output, _ := process.run_command (inst.buffer, received_input)
        zd.send_string (eh, "output", captured_output, msg)
	case:
        fmt.assertf (false, "!!! ERROR: command got an illegal message port %v", msg.port)
    }
}

icommand_instantiate :: proc(name_prefix: string, name: string, owner : ^zd.Eh) -> ^zd.Eh {
    name_with_id := gensym("icommand[%d]")
    instp := new (Command_Instance_Data)
    return zd.make_leaf (name_prefix, name_with_id, owner, instp^, icommand_handle)
}

icommand_handle :: proc(eh: ^zd.Eh, msg: ^zd.Message) {
    inst := eh.instance_data.(Command_Instance_Data)
    switch msg.port {
    case "command":
        inst.buffer = msg.datum.asString (msg.datum)
    case "input":
        received_input := msg.datum.asString (msg.datum)
        captured_output, _ := process.run_command (inst.buffer, received_input)
        zd.send_string (eh, "output", captured_output, msg)
	case:
        fmt.assertf (false, "!!! ERROR: command got an illegal message port %v", msg.port)
    }
}

/////////

probe_instantiate :: proc(name_prefix: string, name: string, owner : ^zd.Eh) -> ^zd.Eh {
    name_with_id := gensym("?")
    return zd.make_leaf (name_prefix, name_with_id, owner, nil, probe_handle)
}

probe_handle :: proc(eh: ^zd.Eh, msg: ^zd.Message) {
    s := msg.datum.asString (msg.datum)
    fmt.eprintf ("probe %v: /%v/ len=%v\n", eh.name, s, len (s))
}

trash_instantiate :: proc(name_prefix: string, name: string, owner : ^zd.Eh) -> ^zd.Eh {
    name_with_id := gensym("trash")
    return zd.make_leaf (name_prefix, name_with_id, owner, nil, trash_handle)
}

trash_handle :: proc(eh: ^zd.Eh, msg: ^zd.Message) {
    // to appease dumped-on-floor checker
}

///
bang_instantiate :: proc(name_prefix: string, name: string, owner : ^zd.Eh) -> ^zd.Eh {
    name_with_id := gensym("bang[%d]")
    return zd.make_leaf (name_prefix, name_with_id, owner, nil, bang_handle)
}

bang_handle :: proc(eh: ^zd.Eh, msg: ^zd.Message) {
    zd.send (eh, "output", zd.new_datum_bang (), msg)
}


////////
literal_instantiate :: proc (name_prefix: string, quoted_name: string, owner : ^zd.Eh) -> ^zd.Eh {
    name_with_id := gensym(quoted_name)
    pstr := string_dup_to_heap (quoted_name [1:(len (quoted_name) - 1)])
    return zd.make_leaf (name_prefix, name_with_id, owner, pstr^, literal_handle)
}

literal_handle :: proc(eh: ^zd.Eh, msg: ^zd.Message) {
    zd.send_string (eh, "output", eh.instance_data.(string), msg)
}

string_constant :: proc (str: string) -> reg.Leaf_Template {
    quoted_name := fmt.aprintf ("'%s'", str)
    return reg.Leaf_Template { name = quoted_name, instantiate = literal_instantiate }
}

string_dup_to_heap :: proc (s : string) -> ^string{
    heap_s := new (string)
    heap_s^ = strings.clone (s)
    return heap_s
}

////////
////////
////////
