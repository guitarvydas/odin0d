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
