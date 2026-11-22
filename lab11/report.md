# Lab 11 – The Race and the Semaphore (Linux)

**Student:** Ciur Alexandrina
**Curs:** Sisteme de Operare, FCIM / UTM, 2026–2027

Toate programele se compilează cu `gcc -Wall -pthread` (sau cu `make`), **fără `-O2`**.

---

## Partea 1 – Vedem race condition-ul (`race.c`)

Output real (3 rulări):

```
counter = 1029050 (expected 2000000)
counter = 1119205 (expected 2000000)
counter = 1303965 (expected 2000000)
```

**1. Cei trei pași reali ai lui `counter++`:**
1. **load:** CPU-ul citește valoarea lui `counter` din memorie într-un registru;
2. **add:** adună 1 la valoarea din registru;
3. **store:** scrie rezultatul din registru înapoi în memorie.

**2. Cum se pierde o adunare:**
Fie `counter = 5`.
- Thread-ul A face *load* și are 5 în registru.
- Înainte ca A să scrie, thread-ul B face și el *load*, tot 5.
- A face *add* (6) și *store*, deci `counter = 6`.
- B face *add* (6) și *store*, deci `counter = 6`.

Au fost două incrementări, dar valoarea a crescut doar cu 1. Scrierea lui B a suprascris-o pe a lui A, iar o adunare s-a pierdut.

**3. De ce rezultatul diferă la fiecare rulare:**
Intercalarea celor două thread-uri o decide planificatorul SO, iar ea depinde de câte nuclee sunt libere, de întreruperi, de alte procese și de cache. Momentele în care un thread e întrerupt între *load* și *store* nu sunt deterministe. De aceea numărul de adunări pierdute, deci și rezultatul, e altul la fiecare rulare.

---

## Partea 2 – Reparăm: mutex, apoi semafor

Output `mutex` și `sem`, câte 3 rulări fiecare:

```
counter = 2000000 (expected 2000000)   (de 6 ori)
```

Timpi măsurați cu `time`:

| Program | Rezultat | real |
|---|---|---|
| race   | 1774285 (greșit) | 0.007 s |
| mutex  | 2000000 | 0.156 s |
| sem    | 2000000 | 0.148 s |
| atomic (opțional) | 2000000 | 0.040 s |

**1. Răspunsul e mereu 2 000 000?**
Da. La toate rulările, atât `mutex` cât și `sem` dau exact 2 000 000. Secțiunea critică (`counter++`) e executată de un singur thread o dată, deci cei trei pași nu se mai intercalează.

**2. `sem_init(&s, 0, 2)`:**
Am încercat și am obținut `counter = 1837182` și `counter = 1881306`, deci rezultatul e din nou greșit. Semaforul pornește de la 2, așa că ambele thread-uri pot face `sem_wait` fără să aștepte (2 → 1 → 0) și intră **simultan** în secțiunea critică. Semaforul nu mai asigură excluderea mutuală și race condition-ul revine. Ca să se comporte ca un lock, valoarea inițială trebuie să fie 1.

**3. De ce e mai lentă versiunea cu lock:**
- Fiecare incrementare costă în plus un `lock` și un `unlock`, adică operații atomice pe memorie cu bariere, de 2 milioane de ori.
- Thread-urile se așteaptă unul pe altul, deci lucrează practic în serie, nu în paralel.
- La conflict se poate ajunge în kernel (futex), adică la context switch.
- Linia de cache cu lock-ul și cu `counter` „sare” între nuclee.

Versiunea `race` e rapidă tocmai pentru că nu face nimic din toate astea, dar dă un rezultat greșit.

---

## Partea 3 – Semaforul ca semnal (`order.c`)

Output:

```
B: waiting for the message...
A: message written
B: I read "hello"
```

B afișează imediat prima linie, apoi programul stă o secundă, apoi apar liniile lui A și B.

**1. Cu `sem_init(&ready, 0, 1)`:**

```
B: waiting for the message...
B: I read ""
A: message written
```

B citește un **șir gol**. Semaforul pornește de la 1, deci `sem_wait` din B reușește imediat (1 → 0) și B nu mai așteaptă. Citește `message` înainte ca A să apuce să scrie (A doarme 1 s), iar `message` e o variabilă globală inițializată cu zerouri, adică șirul vid.

**2. Ce înseamnă un semafor care pornește de la 0:**
Un semafor inițializat cu 0 e o „ușă închisă”, adică un semnal: cine face `sem_wait` se blochează până când alt thread anunță prin `sem_post` că evenimentul așteptat s-a produs.

---

## Partea 4 – Semaforul ca numărător: parcarea (`parking.c`)

Output (PLACES = 3):

```
car 1 enters (inside: 1)
car 2 enters (inside: 2)
car 3 enters (inside: 3)
car 2 leaves (inside: 2)
car 1 leaves (inside: 1)
car 3 leaves (inside: 0)
car 4 enters (inside: 1)
car 6 enters (inside: 2)
car 5 enters (inside: 3)
car 6 leaves (inside: 2)
car 4 leaves (inside: 1)
car 5 leaves (inside: 0)
```

**1. Cea mai mare valoare a lui `inside` și ce o garantează:**
Maximul e **3**. Îl garantează `sem_wait(&places);` împreună cu `sem_init(&places, 0, PLACES);`. Semaforul pornește de la 3 și fiecare mașină care intră ia o unitate. Când valoarea ajunge la 0, a patra mașină se blochează în `sem_wait` până când o mașină care pleacă face `sem_post(&places)`. Mutexul protejează doar variabila `inside` și `printf`, nu limitează numărul de mașini.

**2. Cu `PLACES = 1`:**

```
car 2 enters (inside: 1)
car 2 leaves (inside: 0)
car 1 enters (inside: 1)
car 1 leaves (inside: 0)
...
car 6 enters (inside: 1)
car 6 leaves (inside: 0)
```

Semaforul devine un **semafor binar, adică un mutex/lock**: o singură mașină poate fi în parcare la un moment dat, deci mașinile intră strict pe rând. Programul durează acum circa 6 s în loc de circa 2 s.

---

## Opțional – `atomic.c`

```
counter = 2000000 (expected 2000000)
real 0m0.040s
```

`atomic_fetch_add` face load, add și store ca o singură instrucțiune indivizibilă a CPU-ului (pe x86, `lock xadd`). Rezultatul e corect fără niciun lock și e de circa 4 ori mai rapid decât mutexul (0.04 s față de 0.156 s), pentru că nu există blocare și nici intrare în kernel.
