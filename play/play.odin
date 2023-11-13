package play
import "core:fmt"

Vector3 :: distinct [3]f32
Quaternion :: distinct quaternion128

// NOTE(bill): For the above basic examples, you may not have any
// particular use for it. However, my main use for them is not for these
// simple cases. My main use is for hierarchical types. Many prefer
// subtyping, embedding the base data into the derived types. Below is
// an example of this for a basic game Entity.

Entity :: struct {
    id:          u64,
    name:        string,
    position:    Vector3,
    orientation: Quaternion,
    
    attachment: any,
}

Frog :: struct {
    jump_height:  f32,
}

Monster :: struct {
    is_robot:     bool,
    is_zombie:    bool,
}

main :: proc () {
    // More realistic examples
    {
        // See `parametric_polymorphism` procedure for details
        new_entity :: proc($Attachment: typeid) -> ^Entity {
            e := new(Entity)
            a := new(Attachment)
            e.attachment = a^
            return e
        }
        
        entity := new_entity(Monster)

	m := &entity.attachment
	fmt.eprintf ("entity %v\n", entity)
	attachment := &entity.attachment.(Monster)
	fmt.eprintf ("type attachment=%v\n", typeid_of (type_of (attachment)))
	fmt.eprintf ("type attachment.is_zombie=%v\n", typeid_of (type_of (attachment.is_zombie)))
	fmt.eprintf ("value attachment.is_zombie=%v\n", attachment.is_zombie)
	attachment.is_robot = true
	fmt.eprintf ("type attachment.is_zombie=%v\n", typeid_of (type_of (attachment.is_zombie)))
	fmt.eprintf ("value attachment.is_zombie=%v\n", attachment.is_zombie)
	fmt.eprintf ("entity %v\n", entity)
	fmt.eprintf ("entity.attachment %v\n", entity.attachment)
        
        switch a in entity.attachment {
        case Frog:
            fmt.println("Ribbit")
        case Monster:
            if a.is_robot  { fmt.println("Robotic") }
            if a.is_zombie { fmt.println("Grrrr!")  }
            fmt.println("I'm a monster")
        }
    }
}
