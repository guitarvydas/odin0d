#!/usr/bin/env python3
import sys
i = 60000000
print (f'Y {i}', file=sys.stderr)
while (i > 0):
    i -= 1
print (f'Y {i}', file=sys.stderr)
print ("Y-done")
