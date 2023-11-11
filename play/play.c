#include <stdlib.h>
#include <stdio.h>

typedef struct s_Item {
  int i;
} Item;

typedef struct s_Box {
  Item* item;
} Box;

Box *make_box (Item *sub) {
  Box* pbox = (Box *)malloc(sizeof(Box));
  pbox->item = sub;
  return pbox;
}

int main () {
  Item *pitem = (Item*)malloc(sizeof(Item));
  Box *pbox = make_box (pitem);
  pbox->item->i = 42;
  printf ("%d\n", pbox->item->i);
}
