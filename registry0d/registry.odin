package registry0d

import "core:fmt"
import "../syntax"
import "core:log"
import "core:encoding/json" 

import zd "../0d"

Registry_Stats :: struct {
    nleaves : int,
    ncontainers : int,
    ninstances : int
}

Component_Registry :: struct {
    templates: map[string]Template,
    stats : Registry_Stats,
}

Template_Kind :: enum {Leaf, Container}

Container_Template :: struct {
    name: string,
    decl: syntax.Container_Decl,
}

Leaf_Template :: struct {
    name: string,
    instantiate: proc(name_prefix: string, name: string, owner : ^zd.Eh) -> ^zd.Eh,
}

Leaf_Instantiator :: Leaf_Template

Template :: union {
    Leaf_Template,
    Container_Template,
}


make_component_registry :: proc(leaves: []Leaf_Template, container_xml: string) -> Component_Registry {

//    dump_diagram (container_xml)

    reg: Component_Registry

    for leaf_template in leaves {
	fmt.assertf (!(leaf_template.name in reg.templates), "Leaf \"%v\" already declared", leaf_template.name)
        reg.templates[leaf_template.name] = leaf_template
	reg.stats.nleaves += 1
    }

    decls, err := syntax.parse_drawio_mxgraph(container_xml)
    assert(err == .None, "Failed parsing container XML")

    for decl in decls {
        container_template := Container_Template {
	    name=decl.name,
            decl = decl,
        }
	fmt.assertf (!(decl.name in reg.templates), "component \"%v\" already declared", decl.name)
        reg.templates[decl.name] = container_template
	reg.stats.ncontainers += 1
    }

    return reg
}

get_component_instance :: proc(reg: ^Component_Registry, name_prefix: string, name: string, owner : ^zd.Eh) -> (instance: ^zd.Eh, ok: bool) {
    descriptor: Template
    descriptor, ok = reg.templates[name]
    if ok {
        switch template in descriptor {
        case Leaf_Template:
            instance = template.instantiate(name_prefix, name, owner)
        case Container_Template:
            instance = container_instantiator(reg, owner, name_prefix, template.decl)
        }
	reg.stats.ninstances += 1
    }
    return instance, ok
}

container_instantiator :: proc(reg: ^Component_Registry, owner : ^zd.Eh, name_prefix: string, decl: syntax.Container_Decl) -> ^zd.Eh {

    container_name := fmt.aprintf ("%s.%s", name_prefix, decl.name)
    container := zd.make_container(container_name, owner)

    children := make([dynamic]^zd.Eh)

    // this map is temporarily used to ensure connector pointers into the child array
    // line up to the same instances
    child_id_map := make(map[int]^zd.Eh)
    defer delete(child_id_map)

    // collect children
    {
        for child_decl in decl.children {
            child_instance, ok := get_component_instance(reg, container_name, child_decl.name, container)
            fmt.assertf (ok, "\n*** Error: Can't find component %v\n", child_decl.name)
            append(&children, child_instance)
            child_id_map[child_decl.id] = child_instance
        }
        container.children = children[:]
    }

    // setup connections
    {
        connectors := make([dynamic]zd.Connector)

        for c in decl.connections {
            connector: zd.Connector

            target_component: ^zd.Eh
            target_ok := false

            source_component: ^zd.Eh
            source_ok := false


            switch c.dir {
            case .Down:
                connector.direction = .Down
                connector.sender = {
		    "",
                    nil,
                    c.source_port,
                }
                source_ok = true

                target_component, target_ok = child_id_map[c.target.id]
                connector.receiver = {
		    target_component.name,
                    &target_component.input,
                    c.target_port,
                }
            case .Across:
                connector.direction = .Across
                source_component, source_ok = child_id_map[c.source.id]
                target_component, target_ok = child_id_map[c.target.id]

                connector.sender = {
		    source_component.name,
                    source_component,
                    c.source_port,
                }

                connector.receiver = {
		    target_component.name,
                    &target_component.input,
                    c.target_port,
                }
            case .Up:
                connector.direction = .Up
                source_component, source_ok = child_id_map[c.source.id]
                connector.sender = {
		    source_component.name,
                    source_component,
                    c.source_port,
                }

                connector.receiver = {
		    "",
                    &container.output,
                    c.target_port,
                }
                target_ok = true
            case .Through:
                connector.direction = .Through
                connector.sender = {
		    "",
                    nil,
                    c.source_port,
                }
                source_ok = true

                connector.receiver = {
		    "",
                    &container.output,
                    c.target_port,
                }
                target_ok = true
            }

            if source_ok && target_ok {
                append(&connectors, connector)
            } else if source_ok {              
	      fmt.println ("no target", c)
            } else {              
	      fmt.println ("no source", c)
	    }
        }

        container.connections = connectors[:]
    }

    return container
}

append_leaf :: proc (template_map: ^[dynamic]Leaf_Instantiator, template: Leaf_Template) {
    append (template_map, template)
}

dump_registry:: proc (reg : Component_Registry) {
  fmt.println ()
  fmt.println ("*** PALETTE ***")
  for c in reg.templates {
    fmt.println(c);
  }
  fmt.println ("***************")
  fmt.println ()
}

dump_diagram :: proc (container_xml: string) {
    decls, _ := syntax.parse_drawio_mxgraph(container_xml)
    diagram_json, _ := json.marshal(decls, {pretty=true, use_spaces=true})
    fmt.println(string(diagram_json))
}

print_stats :: proc (reg: ^Component_Registry) {
    fmt.printf ("registry statistics: %v\n", reg.stats)
}
