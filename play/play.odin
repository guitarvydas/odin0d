package play
import "core:fmt"

Eh :: struct {
    instance_data: any,
}

SleepInfo :: struct {
    counter : int,
}

new_eh :: proc (pinst : ^SleepInfo) -> ^Eh {
    eh := new (Eh)
    eh.instance_data = pinst
    eh.instance_data.(^SleepInfo).counter = 2
    return eh
}

fill_stack_with_junk :: proc () {
    array := [?]int { 10, 20, 30, 40, 50, 10, 20, 30, 40, 50, 10, 20, 30, 40, 50, 10, 20, 30, 40, 50 }
}

main :: proc () {
    pinst := new (SleepInfo)
    eh := new_eh (pinst)
    fill_stack_with_junk ()
    i := eh.instance_data.(^SleepInfo).counter
}
