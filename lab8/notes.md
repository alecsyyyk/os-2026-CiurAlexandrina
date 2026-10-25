# Lab 8 – notes (Ciur Alexandrina, FAF-241)

## Part 1 – run inside xv6

**1. Three calls in xv6 vs. Linux.**
xv6: `fork()`, `exec()`, `wait()`. Linux (Lab 7): `fork()`, `execlp()`, `waitpid()`.
The idea and order are the same: copy the process, turn the child into another
program, wait for it in the parent. Only details differ: xv6 `exec` takes a path and
an argv array and does not search PATH; xv6 `wait` gives the exit code directly,
on Linux it is packed in the status and read with `WEXITSTATUS`.

**2. Who prints "hello from the child"?**
`echo`. After a successful `exec` the child's code is replaced by echo; run only
prepared the arguments. That is why "exec failed" is not printed.

**3. Why status 1 here and 127 on Linux?**
The status is the value passed to `exit` after a failed exec: `exit(1)` in the xv6
run.c, `exit(127)` in the Lab 7 run.c. The kernel adds nothing; 127 is just the bash
convention for "command not found".

## Part 2 – pingpong

**1. Why two pipes?**
A pipe is one-way. With one pipe for both directions a process could read back its
own byte before the other side gets it, so there is no guarantee who receives what.
Two pipes give each direction its own channel.

**2. Which call makes the parent wait?**
`read(c2p[0], &b, 1)`. The pipe is empty until the child writes the byte back, and
read on an empty pipe blocks. `wait(0)` only collects the finished child afterwards.

## Outputs
```
$ run
parent: my pid is 3
child: my pid is 4
hello from the child
parent: child 4 ended with status 0
$ pingpong
6: received ping
5: received pong
```
