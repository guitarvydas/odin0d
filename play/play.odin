package play
import "core:fmt"

Item :: struct {
    i : int
}

Box :: struct {
    item : ^Item // <- I need this to be 'any', since any kind of item might be stuffed into this slot
}

make_box :: proc (sub : ^Item) -> ^Box { // <- does this need to be 'any' too?
    pbox := new (Box)
    pbox.item = sub
    return pbox
}

main :: proc () {
    pitem := new (Item)
    pbox := new (Box)
    pbox.item = pitem
    pbox.item.i = 42
    fmt.printf("%d\n", pbox.item.i)
}
