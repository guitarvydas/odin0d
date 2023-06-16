In `demo_drawio/main.odin`, we create a Leaf that spends a considerable amount of time to produce a result.

The name of the Leaf is `Sleep`.  It is meant to simulate actual slow I/O.  In this simulation, the Leaf just wastes time, but, in a real situation, the Leaf might spawn off an I/O process that takes some milliseconds to complete.  I.E. the I/O might be 1,000x slower than the rest of the Leaves in the system.  The system needs to stall waiting for the I/O to complete.

We are considering at least 2 approaches to solving this problem, and, we are simulating such a system to help understand the issues in practice and to prove out the approaches.

One approach is to construct Containers that do not run to completion in one fell swoop, but mete out single small *steps* to their children.  A Leaf runs to completion, but a Container runs in a breadth-first manner, asking each child to perform a single step, then doing this breadth-first stepping until all children have subsided (reach an *idle* state, or *quiesence* in Ceptre lingo).

Another approach is to run all children to completion, but to build I/O Leaves in a special way that sends feedback messages to themselves, while they wait for I/O completion.  The feedback messages are given a higher priority and are dealt with first before any other message is consumed.  In this case, we augment the *input* and *output* queues of a Leaf component with a 3rd queue, a priority queue, which we currently call the*yield queue*.  Handlers for I/O Leaves are written to split the work into 2 parts
1. if the I/O has not yet finished, the Leaf sends itself a *wait* message on its priority channel
2. when the I/O has finished, the Leaf proceeds in a "normal" manner and processes the incoming message as if no waiting had occurred.

In this current simulation, we deal with the *yield queue* approach.  We have augmented the data structures in the general *Eh* structure to include a *yield queue* and we create a special kind of message, called `Sleep_Data`, that holds a simulated I/O timeout value plus the original message.

When the *handler* for our I/O component is called, it receives the following structure as a parameter:

![[2023-06-16-Sleep_Data Working Paper 2023-06-16 05.30.39.excalidraw.png]]
%%[[2023-06-16-Sleep_Data Working Paper 2023-06-16 05.30.39.excalidraw.md|🖋 Edit in Excalidraw]], and the [[2023-06-16-Sleep_Data Working Paper 2023-06-16 05.30.39.excalidraw.dark.png|dark exported image]]%%
![[2023-06-16-Sleep_Data Working Paper 2023-06-16 04.55.41.excalidraw]]

The 3-slot struct (I/O tracking + Message) is passed as a *by-value* parameter to the handler on the callstack, while the rest of the data is allocated on the *heap*.

The handler needs to take 1 of 2 actions
1. It Sends a clone of the {I/O tracking, Message} struct on to itself as feedback on the priority queue, or,
2. It deals with the original message, {port, datum}.  In this simulation, it simply sends the *datum* of the original message to its *output* port.

As it stands - before any optimization has been considered - Messages are blindly cloned to the heap and then Sent.
1. In the feedback case, the *handler* must clone the 3 slots and then deep-clone the *port* and deep-clone the *datum*.  Deep-cloning of the priority message is done by creating a Sleep_Data struct on the heap (a *clone*), then, by simply calling `clone_message` in the `0d.odin` kernel with the Message portion of the Sleep_Data struct.  This proc takes care of deep-cloning the  *port* and the *datum*.  We copy the *init* value from the parameter into the cloned version, then we insert the newly-cloned Message into the message portion of the cloned struct.
2. In the proceed case, the original Message consists of the *port* and the *datum*.  In this simulation, we need to create a new *port* "output" and we need to deep-clone the *datum* (as above).  This can be done by deep-cloning the *datum* using the *clone_datum* proc in `datum.odin`, then creating a fresh message using the `make_message` proc in the `0d.odin` kernel.