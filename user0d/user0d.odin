package user0d

import "core:fmt"

import reg "../registry0d"
import zd "../0d"
import leaf "../leaf0d"

start_logger :: proc () -> bool {
    return false
}

components :: proc (leaves: ^[dynamic]reg.Leaf_Initializer) {
    append(leaves, reg.Leaf_Instantiator { name = "1then2", init = leaf.deracer_instantiate })
    append(leaves, reg.Leaf_Instantiator { name = "?", init = leaf.probe_instantiate })
    append(leaves, reg.Leaf_Instantiator { name = "stringconcat", init = leaf.stringconcat_instantiate })
    append(leaves, reg.Leaf_Instantiator { name = "literalgrep", init = leaf.literalgrep_instantiate })
    append(leaves, reg.Leaf_Instantiator { name = "literalvsh", init = leaf.literalvsh_instantiate })
    append(leaves, reg.Leaf_Instantiator { name = "literalpsgrepwcl", init = leaf.literalpsgrepwcl_instantiate })
    append(leaves, reg.Leaf_Instantiator { name = "command", init = leaf.command_instantiate })
    append(leaves, reg.Leaf_Instantiator { name = "icommand", init = leaf.icommand_instantiate })

    append(leaves, reg.Leaf_Initializer {
        name = "literalwcl",
        init = leaf.literalwcl_instantiate,
    })
    append(leaves, reg.Leaf_Initializer {
        name = "hard_coded_ps",
        init = leaf.hard_coded_ps_instantiate,
    })
    append(leaves, reg.Leaf_Initializer {
        name = "hard_coded_grepvsh",
        init = leaf.hard_coded_grepvsh_instantiate,
    })
    append(leaves, reg.Leaf_Initializer {
        name = "hard_coded_wcl",
        init = leaf.hard_coded_wcl_instantiate,
    })


}

run :: proc (main_container : ^zd.Eh) {
    main_container.handler(main_container, zd.make_message("input", zd.Bang))
}


