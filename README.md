# Sums of Consecutive Squares Solver

## Work Unit Size
The **work unit size** is the number of sub-problems that a worker receives in a single request from the boss.

- In this implementation, the work unit size is calculated as:

```gleam
chunk_size = (max_start + num_workers - 1) / num_workers
```

* The best performance was achieved with a work unit size of **2,500,001 sub-problems per worker** for **n = 10,000,000** and 4 workers.

### How this was determined
Different work unit sizes were tested while measuring total runtime.
* Small sizes → too much communication overhead between boss and workers.
* Large sizes → some workers finished earlier than others, causing imbalance.
* The chosen size gave the fastest total runtime while keeping workers busy evenly.

## Example Run: `gleam run 1000000 4`

### Output
The program produced the following results:
```
Compiled in 0.84s
Running my_project.main
No valid solutions found
```

## Timing Results
Measured using PowerShell (`Start-Process`) to obtain real (wall-clock) time and CPU time:
```
Real time: 00:00:00.6339313
CPU time: 0.03125
CPU/Real: 4.92 %
```

## Largest Problem Solved
The largest problem successfully solved with this implementation was:
```
gleam run 10000000 2
```
### Output
```
3
20
119
696
4059
23660
137903
803760
4684659
```
This was solved with reasonable runtime and memory usage.

## Notes
* The program uses the **actor model** to split the search space across multiple workers.
* Performance depends heavily on the **work unit size**.
* Future improvements could include adaptive chunking or dynamic load balancing to improve efficiency.

