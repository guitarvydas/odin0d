#!/usr/bin/env python3
import sys
i = 20000000
print (f'B {i}', file=sys.stderr)
while (i > 0):
    i -= 1
print (f'B {i}', file=sys.stderr)
print ("B-done")
