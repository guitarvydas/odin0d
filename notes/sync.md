```
def handle(self, port, message):
  switch (state):
    case *:
      switch (port):
        case a:
          r = DoSomethingWithA (message.data)
          send(firstOutput, r)
        case b:
          r = DoSomethingWithB (message.data)
          send(secondOutput, r)
```


```
def handle(self, port, message):
  switch (state):
    case wait:
      switch (port):
        case a: saved [a] = message.data ; state = wait_for_b
        case b: saved [b] = message.data ; state = wait_for_a
    case wait_for_a:
      switch (port):
        case a: saved [a] = message.data ; state = do_something
    case wait_for_b:
      switch (port):
        case b : saved [b] = message.data ; state = do_something
    case do_something:
      switch (port):
        case *: send (output, saved [a] + saved [b]) ; state = wait
```
