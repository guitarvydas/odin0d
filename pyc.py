#!/usr/bin/env python3
import sys
i = 30000000
print (f'C {i}', file=sys.stderr)
while (i > 0):
    i -= 1
print (f'C {i}', file=sys.stderr)
print ("C-done")
