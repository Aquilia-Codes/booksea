# Dokumentacija projekta Booksea — migracija backend sustava

*Radna verzija dokumentacije, ažurira se tijekom izrade projekta. Cilj je da
do kraja migracije ovaj dokument naraste na cca. 15–20 stranica sa slikama
sučelja i dijagramima arhitekture.*

---

## Sadržaj

1. [Uvod](#1-uvod)
2. [Analiza postojećeg sustava](#2-analiza-postojećeg-sustava)
3. [Odabir nove tehnologije](#3-odabir-nove-tehnologije)
4. [Priprema aplikacije za migraciju](#4-priprema-aplikacije-za-migraciju)
5. [Dizajn baze podataka](#5-dizajn-baze-podataka)
6. [Implementacija backend sustava](#6-implementacija-backend-sustava)
7. [Sigurnost i kontrola pristupa](#7-sigurnost-i-kontrola-pristupa)
8. [Otvorena pitanja i sljedeći koraci](#8-otvorena-pitanja-i-sljedeći-koraci)

---

## 1. Uvod

Booksea je aplikacija za upravljanje rezervacijama plovila (moguća je
primjena i na kajake, daske za surfanje i slično) namijenjena vlasnicima i
iznajmljivačima plovila. Aplikacija omogućuje upravljanje turama, gostima,
grupama rezervacija, QR kodovima za ulaznice te pretragu i filtriranje
dostupnih termina. Razvijena je u Flutteru, što znači da se ista aplikacija
može pokrenuti na Androidu, iOS-u i desktop platformama iz jedne baze koda.

Aplikacija je od početka razvoja koristila Firebase (Firestore za bazu
podataka i Firebase Authentication za prijavu korisnika putem Google računa)
kao svoj backend. Tijekom razvoja pokazalo se da Firebase projekt korišten za
aplikaciju više nije dostupan (izgubljen pristup projektu), zbog čega je
odlučeno da se cijeli backend sustav zamijeni vlastitim rješenjem umjesto
čekanja na ponovno uspostavljanje pristupa starom projektu.

Ovaj dokument prati proces migracije: analizu postojećeg sustava, odabir
nove tehnologije, dizajn baze podataka i implementaciju backend aplikacije,
uz obrazloženje donesenih odluka. Dokument se piše usporedno s razvojem, pa
pojedina poglavlja predstavljaju trenutno stanje projekta, a ne nužno
konačan oblik sustava.

---

## 2. Analiza postojećeg sustava

Prije same migracije napravljena je analiza postojeće Flutter aplikacije
(`booksea_app`) kako bi se utvrdilo koliko je Firebase zapravo "utkan" u
kodnu bazu, odnosno koliko bi posla bilo potrebno da se ukloni.

Pokazalo se da je pristup podacima već dobro izoliran u četiri datoteke:

- `firestore_database.dart` — glavna klasa sa svim CRUD operacijama (441
  redaka, ukupno 20 javnih metoda),
- `firestore_service.dart` — generička implementacija čitanja/pisanja u
  Firestore (71 redak),
- `firestore_path.dart` — klasa koja popisuje sve putanje do podataka u bazi
  (39 redaka); zanimljivo je da komentar u toj datoteci već doslovno kaže da
  će "ovo kasnije biti zamijenjeno stvarnom putanjom" — u praksi je to gotov
  popis budućih REST ruta,
- `auth_provider.dart` — upravljanje prijavom i statusom korisnika (193
  retka).

Od ukupno 7.448 redaka Dart koda u aplikaciji, na Firebase otpada otprilike
744 retka (~10%). Čak i dva najveća ekrana u aplikaciji, `home.dart` (2.756
redaka) i `search_and_filter.dart` (2.297 redaka), sadrže samo po jedan
`import` vezan uz Firebase i ništa više — cijela logika prikaza, kalendara,
filtriranja i formi za rezervacije ne ovisi izravno o Firebaseu.

Zbog toga je odlučeno da se zamjeni samo sloj za pristup podacima i
autentikaciju, dok korisničko sučelje ostaje gotovo nepromijenjeno. Time se
izbjegava paralelno rješavanje dva velika problema (migracija backenda i
eventualno planirano preuređenje arhitekture prema BLoC uzorku), što bi
znatno povećalo rizik da se projekt zaglavi.

### 2.1 Uočeni nedostaci u postojećoj implementaciji

Analizom `firestore_database.dart` uočene su tri greške u logici koje
migracija na relacijsku bazu podataka rješava "u hodu", kroz sam dizajn
sheme, umjesto naknadnim zakrpama:

1. **Ukupna cijena ture briše se prilikom uređivanja grupe.** Izraz
   `pastPrice - pastPrice + group.price` matematički se svodi na
   `group.price`, čime se ukupna cijena ture postavlja isključivo na cijenu
   jedne (upravo uređivane) grupe, a doprinos svih ostalih grupa se gubi.
2. **Broj pristiglih gostiju (`arrived`) nikad se ne smanjuje.** Prilikom
   brisanja grupe ispravno se smanjuju `filled` i `price`, ali ne i
   `arrived` — ako se obriše grupa koja je već bila označena kao pristigla,
   brojač ostaje trajno napuhan.
3. **Polje `price` tiho se gubi pri spremanju ture.** Metoda `fromMap()`
   čita polje `price`, ali `toMap()` ga nikad ne zapisuje natrag. Ovo je do
   sad prolazilo neopaženo jedino zato što Firestoreova metoda `update()`
   jednostavno ignorira polja koja nedostaju — u relacijskoj bazi s `NOT
   NULL` stupcem ovakva greška bi odmah bila vidljiva.

Zajednički uzrok sve tri greške jest to što su `filled`, `arrived` i `price`
bili ručno održavani (denormalizirani) brojači, ažurirani na više mjesta u
kodu bez ikakve transakcije. Rješenje usvojeno u novom sustavu opisano je u
poglavlju 5.

---

## 3. Odabir nove tehnologije

Za novi backend odabrana je sljedeća tehnologija:

| Dio sustava | Odabrano rješenje |
|---|---|
| Server / API | Express.js (Node.js) uz TypeScript |
| Baza podataka | PostgreSQL |
| ORM | Prisma |
| Autentikacija | Google Sign-In na klijentu, verifikacija na serveru, izdavanje vlastitih JWT tokena |
| Realtime komunikacija | Socket.IO |
| Hosting | Render (web servis + upravljana PostgreSQL baza) |

**Zašto PostgreSQL, a ne neka NoSQL baza (npr. MongoDB)?** Podaci u ovom
sustavu su izrazito relacijski — tvrtka posjeduje plovila, plovila imaju
ture, ture sadrže grupe gostiju (rezervacije), a sve je to povezano stranim
ključevima i zahtijeva spajanje (*join*) podataka prilikom čitanja. MongoDB
je dokumentna baza, po prirodi vrlo slična Firestoreu — odabir dokumentne
baze bi zapravo reproducirao isti problem zbog kojeg se migracija i
provodi, samo pod drugim imenom.

**Zašto Prisma?** Prisma omogućuje definiranje sheme baze u jednoj
deklarativnoj datoteci (`schema.prisma`), iz koje se generira potpuno
tipiziran klijent za TypeScript. To znatno smanjuje mogućnost grešaka pri
pisanju upita u odnosu na ručno pisanje SQL-a, uz zadržavanje mogućnosti
pisanja "sirovih" SQL upita (`$queryRaw`) za napredne slučajeve koje sam ORM
ne podržava (npr. pogled/*view* nad izvedenim vrijednostima, opisano u
poglavlju 5).

**Zašto zadržati `google_sign_in` na Flutter strani?** Prijava korisnika
putem Google računa već je implementirana i testirana na klijentu, pa nema
razloga mijenjati taj dio. Mijenja se samo ono što se događa nakon prijave:
umjesto da Firebase Authentication izravno izdaje token, token koji Google
vrati na klijentu (`idToken`) šalje se novom backendu, koji ga server-side
verificira pomoću biblioteke `google-auth-library` te izdaje vlastiti par
tokena (*access* i *refresh* JWT). Ključno sigurnosno pravilo ovdje jest da
se korisnički identitet nikad ne preuzima izravno s klijenta — uvijek se
izvodi iz verificiranog tokena.

**Zašto Socket.IO za realtime funkcionalnost?** Postojeća aplikacija koristi
Firestoreove tzv. *snapshot listenere* — pretplate koje automatski
osvježavaju sučelje kad se podaci promijene (npr. lista tura na ekranu se
sama ažurira kad netko doda rezervaciju). U novom sustavu tu ulogu preuzima
Socket.IO: kad se dogodi promjena (nova tura, nova grupa, promjena statusa
dolaska), server pošalje samo signal da se nešto promijenilo, a klijent
zatim ponovno dohvati podatke preko postojećeg REST poziva. Prednost ovakvog
pristupa jest da postoji samo jedan put za čitanje podataka (REST poziv), pa
ne postoji rizik da podaci poslani preko socketa i podaci dohvaćeni preko
REST-a s vremenom postanu neusklađeni.

---

## 4. Priprema aplikacije za migraciju

Prije nego što je krenulo pisanje novog backenda, napravljeno je nekoliko
pripremnih koraka na Flutter strani aplikacije:

1. **Nadogradnja alata za razvoj.** U repozitoriju su zatečene nespremljene
   izmjene koje nadograđuju Gradle (8.0 → 9.7.1), Android Gradle Plugin
   (8.1.0 → 9.3.0), Kotlin (2.1.0 → 2.4.10) i `google-services` dodatak
   (4.4.2 → 4.5.0), zajedno s ispravcima nekoliko zastarjelih Flutter API
   poziva (npr. `withOpacity` → `withValues`, `Container` → `SizedBox` gdje
   se ne koristi dekoracija). Te izmjene su pregledane, potvrđeno je da
   aplikacija i dalje prolazi statičku analizu (`flutter analyze`) bez
   grešaka, te su spremljene (*commit*) kao prvi korak migracije.
2. **Privremeno zaobilaženje Firebase prijave.** Budući da Firebase projekt
   više nije dostupan, prijava u aplikaciju je bila potpuno blokirana, što
   je onemogućavalo bilo kakvo testiranje sučelja. Dodana je privremena
   zastavica `kBypassFirebaseAuth` u `auth_provider.dart` koja, kad je
   uključena, potpuno zaobilazi Firebase Authentication i automatski
   prijavljuje "lažnog" korisnika s punim pravima (admin i vlasnik), čime je
   aplikacija ponovno postala testabilna. Ova izmjena je jasno označena kao
   privremena i bit će uklonjena čim nova autentikacija bude spremna
   (poglavlje 6, korak "zamjena autentikacije").
3. **Vođenje radnih bilježaka.** Sve odluke, otkriveni problemi i otvorena
   pitanja bilježe se tijekom rada u datoteci `docs/migration-notes.md`, na
   engleskom jeziku, kao radni materijal iz kojeg se piše ova (hrvatska)
   dokumentacija.

---

## 5. Dizajn baze podataka

Shema baze podataka izvedena je iz šest postojećih Dart modela
(`BoatModel`, `CompanyModel`, `GroupModel`, `TierModel`, `TourModel`,
`TypeModel`), uz prilagodbu relacijskom modelu podataka. Definirana je kroz
Prisma shemu (`backend/prisma/schema.prisma`) iz koje se generira i
odgovarajuća SQL migracija.

Glavne tablice:

- `tiers` — razine pretplate (broj plovila, broj mjesta itd.),
- `companies` — tvrtke, svaka s jedinstvenim `company_code` preko kojeg se
  korisnici pridružuju tvrtki,
- `users` — korisnici, povezani s tvrtkom preko `company_id`, s zastavicama
  `has_access`, `is_admin`, `is_owner`,
- `boats` — plovila, jedinstvena unutar tvrtke po imenu,
- `user_boats` — poveznička tablica koja zamjenjuje staro polje
  `UserModel.boatIds` (lista imena plovila) pravom relacijom korisnik–plovilo,
- `tour_types` — tipovi tura po plovilu (cijena po odrasloj/dječjoj osobi,
  vrijeme, opcije),
- `tours` — ture, s ograničenjem da se vremenski raspon iste ture ne smije
  preklapati s drugom turom istog plovila (vidi niže),
- `booking_groups` — grupe gostiju vezane uz turu (rezervacije).

### 5.1 Izvedene vrijednosti umjesto ručno održavanih brojača

Kao izravno rješenje za tri greške opisane u poglavlju 2.1, polja `filled`,
`arrived` i `price` se u novoj shemi **ne pohranjuju** kao stupci tablice
`tours`, nego se izračunavaju "u letu" pomoću SQL pogleda (*view*)
`tour_totals`:

```sql
create view tour_totals as
select
  t.id as tour_id,
  coalesce(sum(g.adult_count), 0)::int as filled,
  coalesce(sum(g.adult_count) filter (where g.has_arrived), 0)::int as arrived,
  coalesce(sum(g.price), 0)::numeric(10,2) as price
from tours t
left join booking_groups g on g.tour_id = t.id
group by t.id;
```

Ovakav pristup jamči da ove tri vrijednosti nikad ne mogu "otići u krivo"
jer se ne održavaju ručno na više mjesta u kodu — uvijek se izračunavaju
izravno iz stvarnih grupa vezanih uz turu.

### 5.2 Sprječavanje preklapanja termina na razini baze

Stara implementacija je preklapanje termina provjeravala ručno, petljom kroz
sve postojeće ture unutar proširenog vremenskog raspona. U novoj shemi to
zamjenjuje `EXCLUDE USING gist` ograničenje na razini same baze podataka:

```sql
exclude using gist (
  boat_id with =,
  tstzrange(start_time, end_time) with &&
)
```

Ovo ograničenje garantira, na razini PostgreSQL-a, da za isto plovilo ne
mogu postojati dvije ture s preklapajućim vremenskim rasponima — čak i u
slučaju da dva zahtjeva stignu u isto vrijeme, čega ručna provjera u kodu
aplikacije ne bi nužno bila sigurna.

Slično vrijedi i za popunjenost ture prilikom kreiranja grupe: budući da
`tour_totals` pogled izračunava trenutnu popunjenost, a dvije istovremene
rezervacije bi teoretski obje mogle pročitati isti (zastarjeli) broj
popunjenih mjesta prije nego što ijedna upiše svoju, kreiranje grupe je
implementirano unutar baznog transakcijskog bloka koji prvo zaključa redak
ture (`SELECT ... FOR UPDATE`) prije provjere kapaciteta — vidi poglavlje 6.

---

## 6. Implementacija backend sustava

Backend je implementiran kao zaseban Node.js projekt u mapi `backend/`,
neovisan o Flutter aplikaciji. Sastoji se od sljedećih dijelova:

- **Autentikacija** (`src/routes/auth.ts`) — tri rute: `POST /auth/google`
  (verifikacija Google `idToken`-a i izdavanje JWT parova), `POST
  /auth/refresh` (obnavljanje isteklog pristupnog tokena) i `POST
  /auth/logout` (opoziv *refresh* tokena). *Refresh* tokeni se pohranjuju u
  bazu (tablica `refresh_tokens`, dodana mimo izvorne sheme upravo iz ovog
  razloga) i rotiraju pri svakoj upotrebi — svaki *refresh* poziv opoziva
  stari token i izdaje novi par, čime se onemogućuje ponovna upotreba
  ukradenog ili presretnutog tokena.
- **Korisnički profil** (`src/routes/me.ts`) — dohvat i uređivanje vlastitog
  profila te pridruživanje tvrtki putem koda tvrtke.
- **Plovila i ture** (`src/routes/boats.ts`, `src/routes/tours.ts`) — sve
  operacije nad plovilima, turama i pretragom termina.
- **Grupe/rezervacije** (`src/routes/groups.ts`) — upravljanje pojedinačnim
  rezervacijama unutar ture, uključujući označavanje dolaska gosta.
- **Realtime sloj** (`src/sockets.ts`) — Socket.IO sobe organizirane po
  plovilu (`boat:<id>`) i po turi (`tour:<id>`), koje šalju samo signal
  promjene (`tours:changed`, `summary:changed`, `groups:changed`), nikad
  same podatke.

Ukupno je implementirano svih 19 metoda koje je stara `FirestoreDatabase`
klasa nudila, preslikanih na odgovarajuće REST rute (potpun popis nalazi se
u `docs/migration-notes.md`, poglavlje "Route map").

Sav kod prolazi provjeru tipova (`tsc --noEmit`) bez grešaka te je testiran
pokretanjem servera uz privremenu (placeholder) vrijednost baze podataka —
poslužitelj se ispravno pokreće, a rute ispravno odbijaju zahtjeve bez
valjanog tokena. **Stvarno testiranje nad pravom PostgreSQL bazom podataka
još nije provedeno** jer baza (Render ili lokalna) još nije postavljena —
to je planirano kao sljedeći korak.

---

## 7. Sigurnost i kontrola pristupa

Nekoliko sigurnosnih načela dosljedno je primijenjeno kroz cijeli backend:

- **`company_id` se nikad ne preuzima iz URL-a ili tijela zahtjeva**, nego
  se uvijek izvodi iz autentificiranog korisnika (JWT tokena). Time se
  sprječava da jedna tvrtka, mijenjanjem identifikatora u zahtjevu, pristupi
  podacima druge tvrtke.
- **Pristup plovilu provjerava se na dvije razine** — plovilo mora pripadati
  tvrtki korisnika, a osim toga korisnik mora ili biti administrator/vlasnik
  ili imati izričito dodijeljen pristup tom plovilu (preko tablice
  `user_boats`).
- **Uređivanje vlastitog profila je namjerno ograničeno.** Stara
  implementacija je dopuštala da se preko iste metode (`setUser`) mijenjaju
  i osjetljiva polja poput `hasAccess`, `isAdmin` i `isOwner` — praktički
  bilo što na vlastitom dokumentu. Nova ruta `PATCH /me` dopušta isključivo
  izmjenu nadimka i broja telefona; dodjela prava pristupa i uloga trenutno
  nema svoju administratorsku rutu (vidi otvorena pitanja niže).
- **Socket.IO sobe zahtijevaju autentikaciju i provjeru prava** — spajanje
  na sobu za određeno plovilo ili turu prolazi kroz istu provjeru pristupa
  kao i REST rute, čime se sprječava curenje podataka između tvrtki preko
  realtime kanala.

### 7.1 Pitanje više vlasnika po tvrtki (u raspravi)

Otvoreno je pitanje smije li tvrtka imati više od jednog korisnika s ulogom
vlasnika (`is_owner`). S performansne strane razlika je zanemariva — provjera
te zastavice je jedna usporedba u svakom zahtjevu. Sa sigurnosne strane,
razlika nije toliko u riziku koliko u odgovornosti: svaki vlasnik ima
neograničena prava (brisanje tvrtke, promjena bilo čije uloge, uvid u sve
financijske podatke), pa veći broj vlasnika znači i veći broj računa čija
kompromitacija znači potpuni gubitak kontrole nad tvrtkom, bez jedne jasno
odgovorne osobe.

Preporuka je dopustiti više vlasnika po tvrtki (uobičajen scenarij u praksi
— vlasnik plovila prepusti postavljanje sustava trećoj osobi), ali uz dva
ograničenja: novog vlasnika smije promovirati isključivo postojeći vlasnik
(nikad se sam korisnik ne može proglasiti vlasnikom), te da se svaka promjena
uloge bilježi radi mogućnosti naknadne provjere. Ova odluka još nije
implementirana u kodu — čeka se konačna potvrda prije nego što se ugradi u
shemu baze i API rute.

---

## 8. Otvorena pitanja i sljedeći koraci

- Postavljanje PostgreSQL baze podataka (Render ili lokalno za razvoj) —
  bez toga backend implementiran u poglavlju 6 ne može se stvarno testirati.
- Konačna odluka o modelu vlasništva tvrtke (jedan vlasnik naspram više
  vlasnika), opisana u poglavlju 7.1.
- Administratorske rute za dodjelu prava pristupa (`hasAccess`), uloga
  (`isAdmin`) i dodjelu plovila korisnicima — trenutno postoji samo podatkovni
  model, ne i API za to.
- Migracija preostalog dijela Flutter aplikacije: zamjena `Timestamp` tipa
  s `DateTime`, pisanje `ApiDatabase` klase kao zamjene za
  `FirestoreDatabase`, zamjena Firebase autentikacije novim JWT sustavom,
  povezivanje Socket.IO klijenta te, na kraju, potpuno uklanjanje Firebase
  ovisnosti iz projekta.
- Nakon završetka migracije: dopuna ove dokumentacije slikama zaslona
  aplikacije i dijagramom arhitekture sustava, do ciljanih 15–20 stranica.
