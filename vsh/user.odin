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
    return false
}

user_components :: proc (leaves: ^[dynamic]reg.Leaf_Initializer) {
    append(leaves, reg.Leaf_Instantiator { name = "1then2", init = leaf_deracer_instantiate })
    append(leaves, reg.Leaf_Instantiator { name = "?", init = leaf_probe_instantiate })
    append(leaves, reg.Leaf_Instantiator { name = "stringconcat", init = leaf_stringconcat_instantiate })
    append(leaves, reg.Leaf_Instantiator { name = "literalgrep", init = leaf_literalgrep_instantiate })
    append(leaves, reg.Leaf_Instantiator { name = "literalvsh", init = leaf_literalvsh_instantiate })
    append(leaves, reg.Leaf_Instantiator { name = "literalpsgrepwcl", init = leaf_literalpsgrepwcl_instantiate })
    append(leaves, reg.Leaf_Instantiator { name = "command", init = leaf_command_instantiate })
    append(leaves, reg.Leaf_Instantiator { name = "icommand", init = leaf_icommand_instantiate })

    append(leaves, reg.Leaf_Initializer {
        name = "literalwcl",
        init = leaf_literalwcl_instantiate,
    })
    append(leaves, reg.Leaf_Initializer {
        name = "hard_coded_ps",
        init = leaf_hard_coded_ps_instantiate,
    })
    append(leaves, reg.Leaf_Initializer {
        name = "hard_coded_grepvsh",
        init = leaf_hard_coded_grepvsh_instantiate,
    })
    append(leaves, reg.Leaf_Initializer {
        name = "hard_coded_wcl",
        init = leaf_hard_coded_wcl_instantiate,
    })


}

user_run :: proc (main_container : ^zd.Eh) {
    main_container.handler(main_container, zd.make_message("input", zd.Bang))
}


