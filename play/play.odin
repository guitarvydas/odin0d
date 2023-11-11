package play
import "core:fmt"

Eh :: struct {
    instance_data: any,
}

SleepInfo :: struct {
    counter : int,
}

mutate_inst :: proc (a: any) {
    p := a.(^SleepInfo)
    fmt.printf ("&p = N/A p = %p %v type=%v\n", p, p, typeid_of(type_of(p)))
    p.counter = 76
    fmt.printf ("&p = N/A p = %p %v type=%v\n", p, p, typeid_of(type_of(p)))
}

new_eh :: proc (pinst : ^SleepInfo) -> ^Eh {
    eh := new (Eh)
    eh.instance_data = pinst
    fmt.printf ("new_eh.instance_data %p %v\n", eh.instance_data.(^SleepInfo), eh.instance_data.(^SleepInfo))
    eh.instance_data.(^SleepInfo).counter = 65
    fmt.printf ("new_eh.instance_data %p %v\n", eh.instance_data.(^SleepInfo), eh.instance_data.(^SleepInfo))
    return eh
}

main :: proc () {
    pinst := new (SleepInfo)
    pinst.counter = 57
    eh := new_eh (pinst)
    inst := eh.instance_data.(^SleepInfo)
    fmt.printf ("&inst = %v inst = %p %v type=%v\n", &inst, inst, inst, typeid_of(type_of(inst)))
    mutate_inst (inst)
    fmt.printf ("&inst = %v inst = %p %v type=%v\n", &inst, inst, inst, typeid_of(type_of(inst)))
}
