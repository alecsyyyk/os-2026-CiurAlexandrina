// user/user.h
int sync(void);
int sem_init(int, int);   // new: id, start value
int sem_down(int);        // new: take one, or sleep
int sem_up(int);          // new: give one back
