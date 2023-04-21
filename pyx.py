#!/usr/bin/env python3
import sys
i = 40000000
print (f'X {i}', file=sys.stderr)
while (i > 0):
    i -= 1
print (f'X {i}', file=sys.stderr)
print ("X-done")
