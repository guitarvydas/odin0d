I feel like I'm missing a fundamental detail.

I am trying to modify demo.odin to set `entity.is_robot = true`

After line 650, `entity := new_entity(Monster)`...
https://github.com/odin-lang/Odin/blob/b9a813a69db105596988939ef05153faca1f967f/examples/demo/demo.odin#L650

if I add the line 
```
        entity.derived.(Monster).is_zombie = true
```
I get an error, yet, if I add the same(?) assignment broken up, it works
```
    m := &entity.derived.(Monster)
    m.is_zombie = true
```

I don't understand why I get the error.  Comments welcome, thanks...
