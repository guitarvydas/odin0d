I want to create a structure in the heap, then pass a pointer to it to a procedure that creates another structure that include the heap structure as a `any`.

I then want to modify values in the heap structure.

In C, I might say:

```
(Box*) make_container ((Item*)pitem) {
  (Box*)pbox = (Box*)malloc(...);
  pbox->item = pitem;
  return pbox;
}

int main () {
  (Item*)pitem = (Item*)malloc(...);
  (Box*)pbox = make_container(pitem);
  pbox->item->counter = ...;
}
```
