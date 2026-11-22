# Lab 12 – Producer, Consumer and the Other Tools (Linux)

**Student:** Ciur Alexandrina
**Curs:** Sisteme de Operare, FCIM / UTM, 2026–2027

Compilare: `make` (sau `gcc -Wall -pthread -o X X.c`).
`deadlock.c` e versiunea **reparată**; `deadlock_original.c` e versiunea care se blochează, păstrată pentru comparație.

---

## Partea 1 – Producător și consumator (`prodcons.c`)

```
put 1    (in buffer: 1)
put 2    (in buffer: 2)
put 3    (in buffer: 3)
put 4    (in buffer: 4)
            take 1   (in buffer: 3)
put 5    (in buffer: 4)
            take 2   (in buffer: 3)
put 6    (in buffer: 4)
            take 3   (in buffer: 3)
put 7    (in buffer: 4)
            take 4   (in buffer: 3)
put 8    (in buffer: 4)
            take 5   (in buffer: 3)
            take 6   (in buffer: 2)
            take 7   (in buffer: 1)
            take 8   (in buffer: 0)
```

**1. Ce îl oprește pe producător la 4:**
`sem_wait(&empty);`. Semaforul `empty` pornește de la `SIZE = 4` (sloturi libere). După 4 `put`-uri ajunge la 0, iar producătorul se blochează în `sem_wait(&empty)` până când consumatorul ia un element și face `sem_post(&empty)`.

**2. Cine așteaptă la început:**
**Consumatorul.** El pornește primul, dar `full` începe de la 0 (bufferul e gol), deci se blochează în `sem_wait(&full);` până când producătorul pune primul element și face `sem_post(&full)`.

**3. Mutex luat ÎNAINTE de `sem_wait(&empty)`:**

```
put 1    (in buffer: 1)
put 2    (in buffer: 2)
put 3    (in buffer: 3)
put 4    (in buffer: 4)
                      <- se blochează pentru totdeauna (oprit cu Ctrl-C / timeout, exit 124)
```

Programul intră în **deadlock** când bufferul e plin:
- Producătorul ia mutexul, apoi face `sem_wait(&empty)`. `empty` e 0, deci adoarme **ținând mutexul**.
- Consumatorul trece de `sem_wait(&full)`, dar se blochează la `pthread_mutex_lock(&lock)`, pentru că mutexul e la producător.
- Producătorul așteaptă un slot liber, pe care doar consumatorul îl poate elibera, iar consumatorul așteaptă mutexul, pe care doar producătorul îl poate elibera.

Regula care rezultă: **nu adormi pe un semafor ținând un lock**. Ordinea corectă e întâi semaforul (resursa), apoi mutexul.

---

## Partea 2 – Variabila de condiție (`condvar.c`)

```
B: not ready, I sleep
A: message written
B: I read "hello"
```

**1. Ce variabilă reține că mesajul e gata:**
Variabila **`ready`**, protejată de mutexul `lock`. Variabila de condiție `changed` nu reține nimic. Dacă `pthread_cond_signal` e apelat când nimeni nu așteaptă, semnalul se pierde. E doar locul unde B doarme. La semafor, starea era chiar valoarea semaforului.

**2. Cu `if (!ready)` în loc de `while`:**
Funcționează și aici, cu același output, pentru că există un singur scriitor și un singur cititor, iar B e trezit doar după ce `ready = 1`.

**3. De ce scriem totuși `while`:**
- **Spurious wakeup:** standardul POSIX permite ca `pthread_cond_wait` să se întoarcă fără ca cineva să fi apelat `signal`, iar `ready` e încă 0.
- **Alt thread consumă condiția:** cu mai mulți cititori (sau cu `pthread_cond_broadcast`), alt thread poate prinde mutexul primul și poate pune `ready` înapoi la 0 înainte ca thread-ul nostru să revină din `wait`.

Cu `while`, condiția e verificată din nou după fiecare trezire.

---

## Partea 3 – Cititori și scriitori (`readers.c`)

```
writer 1 writes 10   (alone)
reader 1 reads 10   (readers inside: 1)
reader 2 reads 10   (readers inside: 2)
reader 3 reads 10   (readers inside: 3)
writer 2 writes 20   (alone)
```

**1. Ce două linii permit asta:**

```c
if (++readers == 1)  sem_wait(&room);   /* primul cititor încuie camera pentru scriitori */
if (--readers == 0)  sem_post(&room);   /* ultimul cititor o descuie */
```

Doar **primul** cititor ia `room`, iar ceilalți intră fără să-l mai ceară. Camera e eliberată doar de **ultimul** cititor care iese. Scriitorul ia `room` direct, deci e mereu singur.

**2. De ce `readers` are lock-ul propriu (`rlock`):**
`++readers` și `--readers` sunt tot load/add/store, ca `counter++` din Lab 11. Fără `rlock` apar race-uri:
- Doi cititori care intră deodată pot citi amândoi `readers = 0` și pot crede amândoi că sunt „primii”. Al doilea se blochează atunci în `sem_wait(&room)` (deja luat), deși trebuia să citească.
- Invers, la ieșire pot crede amândoi că sunt „ultimii”, deci `sem_post(&room)` se face de două ori și `room` ajunge la 2. Atunci un scriitor poate intra peste cititori, sau doi scriitori deodată.
- Sau niciunul nu vede 0 și camera nu se mai eliberează niciodată, adică scriitorii așteaptă la infinit.

**3. Cititori care sosesc continuu:**
Writer 2 suferă de **starvation (înfometare)**. Cât timp cel puțin un cititor e înăuntru, `readers` nu ajunge la 0 și `room` nu e eliberat. Cititorii noi intră fără să aștepte, iar scriitorul rămâne blocat la `sem_wait(&room)` la nesfârșit, deși sistemul nu e în deadlock. Soluția aceasta favorizează cititorii.

---

## Partea 4 – Construim un deadlock, apoi îl eliminăm

Versiunea originală (`deadlock_original.c`):

```
$ timeout 5 ./deadlock_original; echo "exit code: $?"
two: I have B, I want A
one: I have A, I want B
exit code: 124
```

Versiunea reparată (`deadlock.c`, în `two()` se ia întâi A, apoi B):

```
$ timeout 5 ./deadlock; echo "exit code: $?"
two: I have B, I want A
two: I have both
one: I have A, I want B
one: I have both
done
exit code: 0
```

(Ordinea în care pornesc `one` și `two` poate să difere, dar programul se termină mereu.)

**1. Cine ține ce și ce așteaptă (cercul):**

```
            așteaptă
   one ─────────────────▶ [B]
    ▲                      │
    │ deținut de           │ deținut de
    │                      ▼
   [A] ◀───────────────── two
            așteaptă

   one → B → two → A → one   (ciclu = așteptare circulară)
```

Thread-ul `one` ține **A** și așteaptă **B**. Thread-ul `two` ține **B** și așteaptă **A**. Fiecare așteaptă o resursă ținută de celălalt, iar niciunul nu o eliberează.

**2. Fără `sleep(1)`, rulat de 10 ori:**
Rezultatul (codul de ieșire al fiecărei rulări): `124 0 124 0 0 0 124 0 124 124`, adică s-a blocat de 5 ori din 10.

**Nu** se mai blochează mereu. Fără pauză, de multe ori un thread apucă să ia ambele mutexuri înainte ca celălalt să pornească, iar programul se termină normal. Asta e **mai rău**, pentru că bug-ul devine **intermitent**: trece testele de câteva ori, apoi blochează programul la client, sub altă încărcare a sistemului. E foarte greu de reprodus și de depanat. Cu `sleep(1)` deadlock-ul era garantat, deci ușor de văzut și de reparat.

**3. De ce aceeași ordine a lock-urilor nu dă niciodată deadlock:**
Dacă toate thread-urile iau lock-urile în aceeași ordine globală (A înaintea lui B), cel care ține B a trecut deja de A. Nimeni nu poate ține B și aștepta A, deci condiția de **așteptare circulară** nu se poate forma.
