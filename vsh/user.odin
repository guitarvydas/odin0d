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

user_start_logger :: proc () -> bool {
    return true
}

user_components :: proc (leaves: ^[dynamic]reg.Leaf_Initializer) {
    
    append(leaves, reg.Leaf_Instantiator { name = "1t2", init = leaf_deracer_instantiate })
    append(leaves, reg.Leaf_Instantiator { name = "?", init = leaf_probe_instantiate })
    append(leaves, reg.Leaf_Instantiator { name = "strconcat", init = leaf_stringconcat_instantiate })

}

user_run :: proc (main_container : ^zd.Eh) {
    main_container.handler(main_container, zd.make_message("input2", "vsh"))
    main_container.handler(main_container, zd.make_message("input1", "grep "))
}


