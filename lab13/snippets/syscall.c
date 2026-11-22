// kernel/syscall.c
extern uint64 sys_sync(void);
extern uint64 sys_sem_init(void);   // new
extern uint64 sys_sem_down(void);   // new
extern uint64 sys_sem_up(void);     // new
...
  [SYS_sync]     = sys_sync,
  [SYS_sem_init] = sys_sem_init,    // new
  [SYS_sem_down] = sys_sem_down,    // new
  [SYS_sem_up]   = sys_sem_up,      // new
