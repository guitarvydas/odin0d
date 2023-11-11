package play
import "core:fmt"

Eh :: struct {
    instance_data: any,
}

SleepInfo :: struct {
    counter : int,
}

/* sleep_handler :: proc(eh: ^Eh) { */
/*     info := eh.instance_data.(SleepInfo) */
/*     info.counter = 1 */
/*     // eh.instance_data.(SleepInfo).counter = 2 */
/* } */

/* make_eh :: proc (info : ^SleepInfo) -> ^Eh { */
/*     eh := new (Eh) */
/*     eh.instance_data = info */
/*     return eh */
/* } */

mutate_inst :: proc (a: any) {
    p := a.(^SleepInfo)
    fmt.printf ("&p = N/A p = %p %v type=%v\n", p, p, typeid_of(type_of(p)))
    p.counter = 76
    fmt.printf ("&p = N/A p = %p %v type=%v\n", p, p, typeid_of(type_of(p)))
}

old_main :: proc () {
    inst := new (SleepInfo)
    inst.counter = 56
    fmt.printf ("&inst = %v inst = %p %v type=%v\n", &inst, inst, inst, typeid_of(type_of(inst)))
    mutate_inst (inst)
    fmt.printf ("&inst = %v inst = %p %v type=%v\n", &inst, inst, inst, typeid_of(type_of(inst)))
}

main :: proc () {
    inst := new (SleepInfo)
    inst.counter = 56
    eh := new (Eh)
    eh.instance_data = inst
    fmt.printf ("&inst = %v inst = %p %v type=%v\n", &inst, inst, inst, typeid_of(type_of(inst)))
    mutate_inst (inst)
    fmt.printf ("&inst = %v inst = %p %v type=%v\n", &inst, inst, inst, typeid_of(type_of(inst)))
}
