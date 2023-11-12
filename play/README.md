I think that I am stuck on Odin syntax for expressing this.  Comments, suggestions on how to do this are welcome. I don't mind reading Odin/examples/demo/demo.odin, but, I don't know where to look, nor, how to search for this kind of thing.

I want to create a structure in the heap, then pass a pointer to it to a procedure that creates another structure (Box, say) that includes the heap structure as an `any`.

I then want to modify values in the secondary heap structure through the primary (Box) structure.

I think that Odin's *any* gives me dynamic type checking which, albeit done at runtime, is better than C's `"anything goes via (void*)"`, hence, I want to use *any* as the type of the dynamic field in the Box.

I include working C code below.

Note that the C code uses "void *" to mean "any" (albeit unchecked in C, whereas, Odin does a check).

So, how do I write the following in Odin?...


```
#include <stdlib.h>
#include <stdio.h>

typedef struct s_IntItem {
  int i;
} IntItem;

typedef struct s_Box {
  void* item; // anything can be saved here
} Box;

Box *make_box (void *sub) {
  Box* pbox = (Box *)malloc(sizeof(Box));
  pbox->item = sub;
  return pbox;
}

int main () {
  IntItem *pitem = (IntItem*)malloc(sizeof(IntItem));
  Box *pbox = make_box (pitem);
  ((IntItem*)pbox->item)->i = 45;
  printf ("%d\n", ((IntItem*)pbox->item)->i);
}
```
