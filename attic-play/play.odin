package play
import "core:fmt"

IntItem :: struct {
    i : int
}

Box :: struct {
    anyitem : any
}

make_box :: proc (sub : any) -> ^Box {
    pbox := new (Box)
    pbox.anyitem = sub
    return pbox
}

main :: proc () {
    pitem := new (IntItem)
    pbox := new (Box)
    pbox.anyitem.(^IntItem).i = 44
    fmt.printf("%d\n", pbox.anyitem.(^IntItem).i)
}

/////////

Jeroen — Today at 10:51 AM
Here's an examle with a union  of type pointers.
package make

import "core:fmt"

Box :: union {^Int_Item, ^F32_Item}
Int_Item :: struct {
    i: int,
}
F32_Item :: struct {
    f: f32,
}

make_box :: proc(sub: $T) -> (box: ^Box) {
    box = new(Box)
    box^ = sub
    return
}

print_box :: proc(box: ^Box) {
    switch kind in box {
    case ^Int_Item: fmt.printf("[int] %v\n", kind.i)
    case ^F32_Item: fmt.printf("[f32] %v\n", kind.f)
    }
}

main :: proc() {
    item := new(Int_Item)
    box := make_box(item)
    box.(^Int_Item).i = 45  // Assign as an ^Int_Item specifically
    print_box(box)
}
////////

But you could of course also make a union{int,f32} and store the value on the union itself instead of this indirection.
package make

import "core:fmt"

Box :: union {int,f32}

print_box :: proc(box: ^Box) {
    switch val in box {
    case int: fmt.printf("[int] %v\n", val)
    case f32: fmt.printf("[f32] %v\n", val)
    }
}

main :: proc() {
    box := new(Box)
    box^ = 45
    print_box(box)
}
package make

import "core:fmt"

Box :: union {int,f32}

print_box :: proc(box: ^Box) {
    switch val in box {
    case int: fmt.printf("[int] %v\n", val)
    case f32: fmt.printf("[f32] %v\n", val)
    }
}

main :: proc() {
    box := new(Box)
    box^ = 13.0
    print_box(box)

    // Type assertion
    val := box.(int) or_else 42 // Test if the box contains an `int`, if not return int(42).
    fmt.println(val) // It contained the float 13.0, so we got 42 from `or_else`.
}

////

Pix — Today at 9:01 PM
If you want some decent ai ish help for Odin. Phind.com is very good because it gives you a AI best guess answer and the sources it gets it from so you can go peek the links to get a better understanding as opposed to trusting blindly.
