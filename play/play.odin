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
    p.counter = 3
}

new_eh :: proc (pinst : ^SleepInfo) -> ^Eh {
    eh := new (Eh)
    eh.instance_data = pinst
    eh.instance_data.(^SleepInfo).counter = 2
    return eh
}

main :: proc () {
    pinst := new (SleepInfo)
    pinst.counter = 1
    fmt.printf ("&pinst = %v pinst = %p %v type=%v\n", &pinst, pinst, pinst, typeid_of(type_of(pinst)))
    eh := new_eh (pinst)
    inst := eh.instance_data.(^SleepInfo)
    fmt.printf ("&inst  = %v inst  = %p %v type=%v\n", &inst, inst, inst, typeid_of(type_of(inst)))
    mutate_inst (inst)
    fmt.printf ("&inst  = %v inst  = %p %v type=%v\n", &inst, inst, inst, typeid_of(type_of(inst)))
}
