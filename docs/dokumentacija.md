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
7. [Integracija s Flutter aplikacijom](#7-integracija-s-flutter-aplikacijom)
8. [Postavljanje i puštanje u produkciju](#8-postavljanje-i-puštanje-u-produkciju)
9. [Sigurnost i kontrola pristupa](#9-sigurnost-i-kontrola-pristupa)
10. [Otvorena pitanja i sljedeći koraci](#10-otvorena-pitanja-i-sljedeći-koraci)

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
- **Tvrtke** (`src/routes/companies.ts`) — trenutno samo `POST
  /companies/:id/boats` (dodavanje plovila), dostupno isključivo
  administratoru ili vlasniku tvrtke čiji je `:id` iz URL-a jednak
  `companyId`-u iz JWT tokena prijavljenog korisnika — isti obrazac provjere
  koji se koristi kroz cijeli backend (vidi poglavlje 9).
- **Realtime sloj** (`src/sockets.ts`) — Socket.IO sobe organizirane po
  plovilu (`boat:<id>`) i po turi (`tour:<id>`), koje šalju samo signal
  promjene (`tours:changed`, `summary:changed`, `groups:changed`), nikad
  same podatke.

Ukupno je implementirano svih 19 metoda koje je stara `FirestoreDatabase`
klasa nudila, preslikanih na odgovarajuće REST rute (potpun popis nalazi se
u `docs/migration-notes.md`, poglavlje "Route map").

Sav kod prolazi provjeru tipova (`tsc --noEmit`) bez grešaka.

### 6.1 Testiranje nad stvarnom bazom podataka

Nakon što je backend prvotno testiran samo pokretanjem servera uz
privremenu (placeholder) vrijednost baze podataka, instaliran je lokalni
PostgreSQL 18, migracija je primijenjena, te je napisana skripta za
"zasijavanje" baze (`backend/scripts/seed-smoke-test.ts`, pokreće se s `npm
run seed:smoke`) koja stvara probnu razinu pretplate, tvrtku, korisnika i
plovilo te ispisuje valjan pristupni token — čime se testiranje ne mora
oslanjati na stvarnu Google prijavu.

Ovom skriptom potvrđeno je, izravno protiv pokrenutog servera i prave baze
podataka:

- `GET /me`, `GET /boats/:id`, `POST /boats/:id/tours` rade ispravno,
- preklapanje termina ispravno se odbija s HTTP statusom 409 (`EXCLUDE USING
  gist` ograničenje opisano u poglavlju 5.2),
- provjera kapaciteta prilikom kreiranja grupe (transakcija s `SELECT ...
  FOR UPDATE`) ispravno dopušta grupu unutar kapaciteta, a odbija je (409)
  kad bi kapacitet bio premašen,
- sve tri izvorne Firestore greške (poglavlje 2.1) potvrđeno su ispravljene:
  `tour_totals` pogled ispravno zbraja `filled`/`price` preko svih grupa
  ture, a `arrived` se ispravno vraća na 0 kad se obriše grupa koja je bila
  označena kao pristigla.

Osim toga, testirane su i rute za autentikaciju (`POST /auth/refresh`,
`POST /auth/logout`) izravno protiv baze — token se ispravno rotira pri
obnavljanju (stari token nakon toga vraća 401), a opoziv tokena ispravno
onemogućuje daljnje obnavljanje.

**Otkrivena greška koju `tsc` nije uhvatio.** Ruta `POST
/tours/:id/groups` prosljeđivala je tijelo zahtjeva (nakon Zod validacije)
izravno u Prismin `bookingGroup.create()` pomoću operatora *spread*. Tijelo
zahtjeva sa strane Flutter aplikacije koristi naziv polja
`countryDialogCode`, dok Prisma shema (i baza podataka) očekuje
`countryDialCode`. TypeScriptova provjera "viška" polja (*excess property
checking*) ne primjenjuje se kroz *spread* operator, pa se ovo neslaganje
nije pojavilo kao greška pri kompajliranju, nego tek kao Prismina greška u
izvođenju (runtime). Ispravljeno je eksplicitnim raspakiravanjem i
preimenovanjem polja, po istom obrascu koji je već korišten u `PATCH
/groups/:id`. Ova greška je poučna za ostatak backenda: svaka ruta koja
Zod-validirano tijelo zahtjeva prosljeđuje u Prismin `data:` objekt pomoću
*spread* operatora predstavlja mjesto gdje se neslaganje naziva polja
između Dart i Prisma strane može sakriti od provjere tipova — takva mjesta
vrijedi ručno provjeriti jedno po jedno, umjesto oslanjanja isključivo na
`tsc --noEmit`.

---

## 7. Integracija s Flutter aplikacijom

Nakon što je backend uspješno testiran nad pravom bazom podataka
(poglavlje 6.1), migracija je nastavljena na strani Flutter aplikacije, u
tri koraka koji odgovaraju koracima 5 i 6 plana migracije iz
`docs/migration-notes.md`.

### 7.1 Zamjena sloja za pristup podacima

Napisana je nova klasa `services/api_database.dart` koja implementira svih
19 metoda koje je nudila stara `FirestoreDatabase` (20 minus
`companyExists`, namjerno izostavljena — vidi niže), oslanjajući se na
novi `services/api_client.dart`, tanki HTTP klijent (temeljen na paketu
`http`) koji u memoriji drži JWT tokene i automatski obnavlja pristupni
token nakon HTTP odgovora 401. Svaka referenca na `FirestoreDatabase` u
korisničkom sučelju (`home.dart`, `search_and_filter.dart`,
`qr_scanner_screen.dart`, `no_code_home.dart`, `auth_widget_builder.dart`,
`my_app.dart`, `main.dart`) mehanički je preimenovana u `ApiDatabase` i
preusmjerena na novi *import*. Metoda `companyExists` nema svoj ekvivalent
u `ApiDatabase` jer novi backend tu provjeru radi unutar same rute `POST
/me/company` (vraća 404 ako se kod tvrtke ne poklapa), pa nema više što
provjeravati zasebno.

Rute koje u starom sustavu vraćaju "tok" podataka (`getToursStream`,
`getSumOfPriceStream`, `getGroups`, `searchTours`) u ovoj su fazi
implementirane kao **privremeno rješenje temeljeno na ispitivanju
(*polling*)** — dijeljena pomoćna funkcija `_pollStream` iznova pokreće
odgovarajući REST poziv svakih 5 sekundi. Budući da su potpisi metoda
(`Stream<T>`) ostali identični, korisničko sučelje (`StreamBuilder`
pozivi) uopće ne treba mijenjati; zamjena ovog privremenog rješenja
Socket.IO-em planirana je kao zaseban, kasniji korak (poglavlje 10).

Ova faza je potvrđena ne samo statičkom analizom (`flutter analyze` — 0
grešaka), nego i jednokratnom skriptom
(`tool/smoke_test_api_database.dart`), koja je nad živom bazom podataka
redom prošla kroz `getUser`, `getTourTypesAndBoatInfo`, `createTour`,
`getTours`, `createGroup`, `updateGroupHasArrived`, `getGroups` te
brisanje testnih podataka. Ovim testiranjem otkrivene su tri dodatne
stvarne greške prije nego što bi se pojavile u samoj aplikaci­ji:

1. **ID plovila je zapravo uvijek bio naziv.** Stari Firestore backend
   koristio je `boats.name` kao Firestore ID dokumenta, pa je svugdje kroz
   aplikaciju (uključujući oba padajuća izbornika za odabir plovila)
   "boatId" zapravo bio čitljivi naziv plovila. Nova Postgres shema
   plovilima dodjeljuje pravi UUID, što bi tiho pokvarilo ta dva izbornika
   (prikazivala bi/birala UUID umjesto naziva). Ispravljeno je na
   **backend strani**, ne na Flutter strani: dodana je funkcija
   `getBoatByName` (`backend/src/lib/authz.ts`) koja rute vezane uz plovilo
   u URL-u (`GET/POST /boats/:id...`) razrješava po paru
   (`companyId`, `naziv`) umjesto po primarnom ključu; ruta `/me` sada za
   `boatIdsFor` vraća `boat.name` umjesto `userBoat.boatId`. Rute koje već
   imaju pravi UUID plovila u ruci (razrješavanje stranog ključa `boatId`
   ture ili grupe) i dalje koriste izvorni, ID-temeljeni
   `getAccessibleBoat`. Na Flutter strani nije bila potrebna nijedna
   izmjena.
2. **`UserModel.fromMap` bi puknuo za posve novog korisnika.** API šalje
   `companyId: null` (u Postgresu dopušteno polje) prije nego što se
   korisnik pridruži tvrtki, dok je to polje u `UserModel`-u tipa
   `String` koji ne dopušta `null`. Ispravljeno izrazom
   `data['companyId'] ?? ''`.
3. **Cijela polja (`price`) rušila su aplikaciju kad cijena nema
   decimalu.** Dart izraz `double price = data['price']` baca iznimku kad
   dekodirani JSON broj nema decimalnu točku (npr. `0`, koji se dekodira
   kao `int`, ne `double`) — a upravo takvu vrijednost ima svaka
   novostvorena tura ili grupa. `TypeModel` je već imao zaštitu za svoja
   polja cijene; `TourModel` i `GroupModel` nisu. Ispravljeno je u oba
   izrazom `(data['price'] as num).toDouble()`; istom logikom (uz
   `.round()`, jer je riječ o cijelom broju) ispravljen je i
   `UserModel.provision`, budući da stupac `provision` u bazi dopušta
   decimale iako ih Dart model nije očekivao.

### 7.2 Zamjena autentikacije

Klasa `providers/auth_provider.dart` napisana je iznova, uz zadržavanje
istog `Status` *enuma* i istog `Stream<UserModel> user` sučelja koje
korisničko sučelje već koristi — mijenja se samo ono ispod te površine.
Paket `google_sign_in` (namjerno **nije** nadograđen na verziju 7.x, koja
donosi potpuno drugačiji, nekompatibilan API prijave — dovoljno je da
postojeća verzija 6.2.2 i dalje radi) i dalje se koristi na klijentu za
dobivanje Google `idToken`-a, koji se sada šalje na `POST /auth/google`
umjesto izravno Firebaseu.

Dodano je i ono što je Firebase Authentication ranije davao besplatno, a
sada zahtijeva ručnu implementaciju: **postojanost sesije preko ponovnih
pokretanja aplikacije** — *refresh* token pohranjuje se u
`SharedPreferences` i tiho se iskorištava pri pokretanju aplikacije
(`ApiClient.refreshWithToken`) — te javna metoda
`AuthProvider.refreshUser()`, koja zamjenjuje stari izravni poziv
`onAuthStateChanged(firebaseUser)` nakon što korisnik unese kod tvrtke.

Ova faza je potvrđena testiranjem izravno protiv žive baze podataka:
funkcija `issueTokens` izvezena je iz `backend/src/routes/auth.ts` kako bi
skripta za zasijavanje mogla izdati pravi par pristupnog i *refresh*
tokena, čime su prvi put testirani `POST /auth/refresh` (ispravno rotira
token; stari token odmah nakon toga vraća 401) i `POST /auth/logout`
(ispravno opoziva token; opozvani token se više ne može obnoviti).

**Ono što ostaje stvarno netestirano jest sam interaktivni gumb za Google
prijavu** (`POST /auth/google` s pravim `idToken`-om) — to zahtijeva
prolazak kroz Googleov stvarni zaslon za pristanak (OAuth *consent
screen*) na pokrenutom uređaju ili u pregledniku, što u razvojnom
okruženju korištenom za ovu fazu nije bilo izvedivo. Kod je pažljivo
pregledan (provjerava `idToken` pomoću `google-auth-library` protiv
`GOOGLE_OAUTH_CLIENT_IDS`, korisnika sprema/ažurira po `googleSub`, izdaje
tokene po istom postupku koji je već testiran preko *refresh*/*logout*
ruta), ali test klikom kroz stvarnu prijavu tek predstoji. Privremena
zastavica `kBypassFirebaseAuth` (poglavlje 4, sada podrazumjevano
isključena) ostaje kao siguran plan B ako se pokaže da prijava zahtijeva
dodatan rad.

Datoteke `firestore_database.dart`, `firestore_service.dart` i
`firestore_path.dart` sada su potpuno "osirotjele" (ništa ih više ne
uvozi), ali namjerno su ostavljene u kodnoj bazi — njihovo uklanjanje
planirano je tek u posljednjoj fazi migracije, zajedno s uklanjanjem
Firebase ovisnosti iz `pubspec.yaml` (poglavlje 10).

---

## 8. Postavljanje i puštanje u produkciju

Za hosting backend usluge i baze podataka odabran je [Render](https://render.com)
— usluga koja nudi upravljanu PostgreSQL bazu i web servis za Node.js
aplikacije unutar iste platforme, s besplatnom razinom dovoljnom za razvoj
i demonstraciju projekta.

### 8.1 Ručno postavljanje umjesto Blueprint datoteke

Repozitorij sadrži `render.yaml`, tzv. Render *Blueprint* datoteku koja bi
u teoriji trebala omogućiti da se baza podataka i web servis podignu
jednim klikom ("New" → "Blueprint") izravno iz ovog repozitorija. U praksi
je stvarno postavljanje ipak napravljeno ručno, u dva koraka, jer
Blueprint pristup nije bio isproban unaprijed i nosio je rizik da
migracija stvori posve drugu (praznu) bazu podataka umjesto da se poveže na
već stvorenu:

1. Baza podataka stvorena je prva, ručno, preko "New" → "PostgreSQL".
2. Web servis stvoren je zatim, također ručno, preko "New" → "Web Service",
   izravno povezan s istim repozitorijem, s korijenskom mapom (*root
   directory*) postavljenom na `backend`, naredbom za izgradnju `npm
   install && npm run prisma:generate && npm run build` te naredbom za
   pokretanje `npm run prisma:migrate && npm start` — potonja naredba pri
   svakom postavljanju (*deploy*) prvo primjenjuje eventualne nove
   migracije baze (`prisma migrate deploy`, sigurno za ponovno pokretanje —
   *idempotentno*), a zatim tek pokreće server. Kao vezu prema bazi
   podataka, web servis koristi bazinu *Internal Database URL* vrijednost
   (brža i ne izlazi na javni internet, za razliku od *External* varijante).

`render.yaml` je zadržan u repozitoriju kao dokumentiran, ali **neisproban**
alternativni put — opisuje iste varijable okoline (`DATABASE_URL`,
`GOOGLE_OAUTH_CLIENT_IDS`, JWT tajne koje Render sam generira,
vremena isteka tokena, `CORS_ORIGIN`) kao i ručno postavljena instanca, pa
može poslužiti kao referenca ili kao polazna točka za budući projekt, uz
napomenu da nazive polja treba provjeriti protiv trenutne Render
Blueprint dokumentacije prije stvarne upotrebe.

### 8.2 Potvrda da postavljanje radi

Nakon postavljanja, usluga je dostupna na `https://booksea.onrender.com`.
Ispravan rad potvrđen je s tri jednostavne provjere: `GET /health` vraća
`{"ok":true}`, `GET /me` ispravno vraća 401 bez valjanog tokena (potvrda
da autentikacijski sloj radi i na produkcijskoj instanci), a `GET /`
(dodana ruta koja prije nije postojala — ranije je vraćala 404, što je pri
otvaranju gole adrese u pregledniku djelovalo kao da servis ne radi) vraća
jednostavnu poruku dobrodošlice. `ApiClient.baseUrl`
(`booksea_app/lib/services/api_client.dart`) sada pokazuje na ovu adresu
umjesto na `localhost`/lokalnu mrežu; za lokalni razvoj potrebno ga je
privremeno vratiti nazad (vidi komentar uz to polje u kodu).

### 8.3 Ograničenja besplatne razine

Render-ova besplatna razina nosi dva ograničenja o kojima treba voditi
računa tijekom ostatka projekta:

- **Besplatna instanca PostgreSQL baze ističe i briše se nakon 30 dana.**
  Prihvatljivo za aktivan razvoj, ali prije nego što projekt nadživi taj
  rok potrebno je ili nadograditi na plaćenu razinu, ili periodički
  napraviti sigurnosnu kopiju i ponovno stvoriti instancu.
- **Besplatni web servis "uspavljuje se" nakon perioda neaktivnosti**, pri
  čemu se otvorene veze prekidaju. Ovo je već pokriveno na dvije razine:
  Socket.IO klijent sam ponovno pokušava uspostaviti vezu uz rastući
  razmak između pokušaja (*reconnect with backoff*), a klijent nakon
  ponovnog spajanja iznova dohvaća podatke preko REST poziva. U praksi to
  znači da je prvi zahtjev nakon dužeg mirovanja usluge sporiji — nešto što
  treba očekivati prilikom demonstracije aplikacije nakon stanke.

---

## 9. Sigurnost i kontrola pristupa

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

### 9.1 Pitanje više vlasnika po tvrtki (u raspravi)

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
uloge bilježi radi mogućnosti naknadne provjere. Vezano uz ovo, u razgovoru
o modelu uloga potvrđeno je i sljedeće: tvrtka može imati više
"bookera" (osoba koje u njeno ime kreiraju i upravljaju rezervacijama), a
administratori mogu odobriti (`hasAccess`) novoj osobi pridruživanje toj
grupi — što potvrđuje model uloga koji shema baze već ima (`hasAccess`,
`isAdmin`, `isOwner` po korisniku). Ova odluka o više vlasnika još nije
implementirana u kodu — čeka se konačna potvrda prije nego što se ugradi u
shemu baze i API rute.

---

## 10. Otvorena pitanja i sljedeći koraci

Od prošle verzije ovog poglavlja, sljedeće je riješeno: PostgreSQL baza je
postavljena i backend je stvarno testiran protiv nje (poglavlje 6.1), cijela
Flutter aplikacija je prebačena na novi backend i JWT autentikaciju
(poglavlje 7), a aplikacija je puštena u produkciju na Renderu (poglavlje
8). Preostaje sljedeće:

- **Konačna odluka o modelu vlasništva tvrtke** (jedan vlasnik naspram više
  vlasnika), opisana u poglavlju 9.1.
- **Administratorske rute za dodjelu prava pristupa** (`hasAccess`), uloga
  (`isAdmin`) i dodjelu plovila korisnicima — trenutno postoji samo
  podatkovni model (tablice `users`, `user_boats`), ne i API za to. Bez
  ovoga, jedini način da netko dobije pristup nakon vlasnika/admina jest
  ručna izmjena baze podataka.
- **Klik-test stvarne Google prijave** (`POST /auth/google` s pravim
  `idToken`-om) — jedini dio backenda koji je pregledan, ali nije stvarno
  testiran nijednim automatiziranim putem (poglavlje 7.2), jer zahtijeva
  prolazak kroz Googleov OAuth zaslon na pokrenutom uređaju.
- **Povezivanje Socket.IO klijenta.** Backend već šalje realtime signale
  promjena (poglavlje 6), no Flutter strana ih trenutno prima kroz
  privremeno rješenje temeljeno na ispitivanju svakih 5 sekundi
  (*polling*, poglavlje 7.1) umjesto kroz stvarnu Socket.IO pretplatu.
  Zamjena ne zahtijeva promjenu potpisa metoda na koje se sučelje već
  oslanja.
- **Potpuno uklanjanje Firebase ovisnosti.** Datoteke
  `firestore_database.dart`, `firestore_service.dart` i
  `firestore_path.dart` te privremena zastavica `kBypassFirebaseAuth`
  (`auth_provider.dart`) i `try`/`catch` oko `Firebase.initializeApp()`
  (`main.dart`) i dalje postoje u kodnoj bazi kao "osirotjeli" kod ili
  privremeni oslonac za testiranje — brišu se tek kad je Google prijava
  potvrđeno testirana uživo, zajedno s uklanjanjem `firebase_core`,
  `firebase_auth`, `cloud_firestore` iz `pubspec.yaml` i datoteke
  `google-services.json`.
- **Nadogradnja Render besplatne razine prije isteka od 30 dana**
  (poglavlje 8.3), ili uspostavljanje periodičke sigurnosne kopije baze
  podataka ako nadogradnja nije opcija tijekom trajanja projekta.
- **Isprobavanje `render.yaml` Blueprint pristupa** — trenutno je samo
  dokumentiran, nije stvarno iskorišten za postavljanje (poglavlje 8.1);
  vrijedno je potvrditi da radi kako je zamišljeno, radi buduće
  reproducibilnosti postavljanja (npr. na drugom Render računu).
- Nakon završetka preostalih točaka: dopuna ove dokumentacije slikama
  zaslona aplikacije i dijagramom arhitekture sustava, do ciljanih 15–20
  stranica.
