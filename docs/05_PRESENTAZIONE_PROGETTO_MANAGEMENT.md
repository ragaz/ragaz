# Governed Data Catalog — Progetto di Governance del Patrimonio Dati

## Athora Italia S.p.A. — Direzione Data Warehouse

---

## Executive Summary

Il Data Warehouse di Athora Italia gestisce oggi un patrimonio di oltre 300 oggetti dati
distribuiti su 9 sistemi, alimentati da più di 50 pipeline ETL automatizzate, e utilizzati
per produrre le segnalazioni obbligatorie verso IVASS, Banca d'Italia, e per il calcolo
della solvibilità aziendale tramite MGAlfa.

**Questo patrimonio dati non è oggi censito, classificato né governato in modo strutturato.**

Il progetto Governed Data Catalog nasce per colmare questo gap, creando un registro
centralizzato e governato di tutti i dati aziendali — strutturati e non — con l'obiettivo
di:

- Superare con esito positivo gli audit IVASS sulla qualità e tracciabilità dei dati
- Adeguare la compagnia agli obblighi GDPR (ad oggi non presidiati)
- Ridurre il rischio operativo sulle alimentazioni critiche
- Eliminare le aree di shadow IT (file non governati su rete e PC locali)

Il catalogo è stato progettato interamente su tecnologia Microsoft SQL Server, già in uso
in azienda, senza necessità di acquistare licenze software aggiuntive.

---

## 1. Perché Serve Questo Progetto

### 1.1 Contesto regolamentare

Athora Italia, in qualità di compagnia assicurativa vita vigilata, è soggetta a obblighi
stringenti sulla qualità, tracciabilità e protezione dei dati:

| Normativa | Obbligo | Stato attuale |
|---|---|---|
| **Solvency II** (IVASS) | Tracciabilità dei dati che alimentano i QRT e le riserve tecniche | Parziale. Il flusso verso MGAlfa non è documentato formalmente |
| **Regolamento IVASS 13/2015** | Qualità e coerenza dei dati per i modelli statistici 34, 35, 39, 40, 41 | Parziale. Controlli DQ presenti ma non catalogati |
| **GDPR** (Reg. UE 2016/679) | Registro trattamenti Art. 30, DPIA, diritti interessati, data retention | **Non presidiato** |
| **D.Lgs. 231/2007** (AML) | Tracciabilità dati per autovalutazione rischio antiriciclaggio | Parziale |
| **Banca d'Italia** | Accuratezza segnalazioni residenti esteri | Operativo ma non documentato |

### 1.2 Rischi operativi attuali

Dall'analisi condotta, emergono le seguenti aree di rischio:

**RISCHIO ALTO — Shadow IT non governato**
> Esistono file Excel, CSV e Access condivisi su cartelle di rete **senza alcun controllo
> di accesso** e su PC locali degli utenti **senza backup**. Alcuni di questi file
> **alimentano direttamente processi critici**. In caso di perdita, corruzione o accesso
> non autorizzato non esiste alcun presidio.

**RISCHIO ALTO — Assenza di governance GDPR**
> La compagnia tratta dati personali di decine di migliaia di interessati (contraenti,
> assicurati, beneficiari), inclusi **dati sanitari** (categoria particolare ex Art. 9 GDPR).
> Ad oggi non esiste un registro dei trattamenti, non sono definite le policy di retention,
> e non è stata condotta alcuna DPIA. In caso di ispezione del Garante Privacy, la
> compagnia non sarebbe in grado di dimostrare conformità.
> Le sanzioni GDPR possono raggiungere il **4% del fatturato annuo** o 20 milioni di euro.

**RISCHIO MEDIO-ALTO — Flusso Solvency non documentato**
> I dati di input per MGAlfa vengono assemblati dal DWH unendo due gestionali diversi
> (PASS e Smarthall) attraverso procedure T-SQL. La logica di trasformazione e
> assemblaggio **non è documentata formalmente**. In caso di audit IVASS sul processo
> di calcolo delle riserve tecniche, la compagnia non potrebbe dimostrare in modo
> strutturato la tracciabilità del dato dalla sorgente al QRT.

**RISCHIO MEDIO — Nessuna convenzione di naming**
> Le 300+ tabelle del DWH non seguono una convenzione uniforme di denominazione.
> Questo rende difficile la comprensione del patrimonio dati da parte di nuove risorse
> e aumenta il rischio di errori nelle pipeline ETL.

### 1.3 Cosa succede se non facciamo nulla

| Scenario | Probabilità | Impatto |
|---|---|---|
| Ispezione Garante Privacy senza registro trattamenti | Media | Sanzione fino al 4% del fatturato |
| Audit IVASS che richiede tracciabilità dati Solvency | Alta | Rilievi formali, possibile aumento requisito di capitale |
| Perdita di un file Excel critico su PC locale | Alta | Blocco processo operativo, dato non ricostruibile |
| Data breach su cartella di rete non protetta | Media | Notifica obbligatoria al Garante entro 72 ore, danno reputazionale |
| Uscita di una risorsa chiave del team DWH (5 persone) | Media | Perdita di conoscenza non documentata su pipeline critiche |

---

## 2. Cosa Abbiamo Costruito

### 2.1 Il catalogo in sintesi

Il Governed Data Catalog è un sistema centralizzato che permette di **sapere quali dati
abbiamo, dove sono, da dove vengono, dove vanno, chi ne è responsabile, come sono
classificati e quali obblighi normativi vi sono associati**.

```
┌─────────────────────────────────────────────────────────────────┐
│                    GOVERNED DATA CATALOG                        │
│                                                                 │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   │
│  │ CATALOGO │   │ LINEAGE  │   │   GDPR   │   │GOVERNANCE│   │
│  │          │   │          │   │          │   │          │   │
│  │ Sistemi  │   │ Da dove  │   │ Registro │   │ Workflow │   │
│  │ Asset    │   │ arriva   │   │ trattam. │   │ approva- │   │
│  │ Entità   │   │ il dato  │   │ Art. 30  │   │ tivi     │   │
│  │ Attributi│   │ e dove   │   │ Classif. │   │ Ruoli    │   │
│  │ Glossario│   │ va       │   │ DPIA     │   │ Audit    │   │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘   │
│                                                                 │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐                   │
│  │CLASSIFIC.│   │CRITICITÀ │   │  REPORT  │                   │
│  │   DLP    │   │          │   │REGOLAMNT.│                   │
│  │          │   │ 6 assi   │   │          │                   │
│  │ 4 livelli│   │ di       │   │ IVASS    │                   │
│  │ con      │   │ impatto  │   │ BdI      │                   │
│  │ regole   │   │          │   │ Solvency │                   │
│  └──────────┘   └──────────┘   └──────────┘                   │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Componenti realizzate

| Componente | Stato | Descrizione |
|---|---|---|
| **Database catalogo** | Completato | 30+ tabelle su SQL Server, schema `dcat`, nello stesso server del DWH |
| **Framework classificazione DLP** | Completato | 4 livelli (Pubblico / Interno / Riservato / Strettamente Riservato) con regole operative |
| **Modello GDPR** | Completato | Registro trattamenti Art. 30, basi giuridiche, finalità, categorie interessati |
| **Data Lineage** | Completato | Tracciabilità entità-entità e attributo-attributo, legata alle pipeline ETL |
| **Matrice di criticità** | Completato | Valutazione su 6 assi (regolamentare, operativo, finanziario, reputazionale, GDPR, data loss) |
| **Workflow approvativo** | Completato | 4 workflow (classificazione, nuova entità, trattamento GDPR, glossario) con ruoli e notifiche |
| **Applicazione web** | Completato | Interfaccia consultabile da business e IT (dashboard, ricerca, lineage, governance) |
| **Seed data Athora** | Completato | Tutti i 9 sistemi censiti, 12 data asset, 8 entità hub, 8 report regolamentari |

### 2.3 Scelte tecnologiche

| Scelta | Motivazione |
|---|---|
| SQL Server (stesso server DWH) | Zero costi di licenza aggiuntivi, competenze già presenti nel team |
| ASP.NET Core con Kestrel | Non richiede IIS, si avvia come servizio Windows, leggero |
| Windows Authentication (AD) | Stessa autenticazione già in uso, nessuna gestione password aggiuntiva |
| Dapper (micro-ORM) | Leggero, performante, naturale per chi scrive T-SQL |
| Nessun software commerciale | Nessun costo di licenza Collibra/Alation/Purview (valutabili in futuro) |

**Costo infrastrutturale del progetto: zero.**

---

## 3. Cosa Cambierà Operativamente

### Prima e dopo

| Situazione | PRIMA | DOPO |
|---|---|---|
| "Quali tabelle alimentano il modello IVASS 34?" | Bisogna chiederlo a chi ha scritto la stored procedure | Ricerca nel catalogo, lineage visuale immediato |
| "Dove sono i dati personali dei beneficiari?" | Nessuno lo sa con certezza | Ricerca per flag GDPR, mappa completa |
| "Se cambio questa tabella, cosa si rompe?" | Analisi manuale del codice T-SQL | Impact analysis automatica dal lineage |
| "Il Garante chiede il registro trattamenti" | Non esiste | Registro Art. 30 nel catalogo, esportabile |
| "Chi è responsabile di questo dato?" | Responsabilità implicita e informale | Data Owner e Data Steward assegnati formalmente |
| "Un file Excel critico è stato cancellato" | Panico, tentativo di ricostruzione manuale | Il file era censito, classificato, con backup obbligatorio |
| "Nuovo collega nel team DWH" | Mesi di affiancamento per capire il patrimonio dati | Consulta il catalogo con descrizioni business e tecniche |

### Per il team DWH (5 persone)

- Ogni membro documenta le proprie pipeline e tabelle nel catalogo
- Le regole di data quality vengono censite (non solo implementate nel codice)
- Le nuove entità passano da un workflow approvativo prima di andare in produzione
- Il catalogo diventa il riferimento unico per le riconciliazioni

### Per il business (Attuariato, Risk, Contabilità, Compliance)

- Consultano il catalogo via web per capire quali dati sono disponibili
- Vedono la classificazione e la criticità dei dati che usano
- Possono cercare nel glossario i termini business

---

## 4. Piano di Lavoro

### Fase 1 — Fondazione (Mese 1-2)

| Attività | Chi | Output |
|---|---|---|
| Installazione database catalogo | Team DWH | Schema `dcat` operativo |
| Avvio applicazione web (Kestrel) | Team DWH | URL interno consultabile |
| Censimento automatico metadati SQL Server | Team DWH | Tutte le tabelle/viste caricate nel catalogo |
| Censimento dei 50+ job SQL Agent | Team DWH | Pipeline ETL documentate |
| Nomina Data Owner per ogni sistema | Management | Responsabilità formali assegnate |

### Fase 2 — Classificazione e GDPR (Mese 2-4)

| Attività | Chi | Output |
|---|---|---|
| Classificazione DLP di ogni entità dati | Data Owner + DWH | Livello assegnato a ogni tabella/file |
| Censimento file shadow IT (rete + PC) | Team DWH + Utenti | Inventario completo dei file non governati |
| Migrazione file critici su aree protette | IT Infrastruttura | Cartelle con ACL, fine accesso libero |
| Compilazione registro trattamenti GDPR | DWH + Compliance + DPO | Registro Art. 30 completo |
| Mappatura dati personali/sensibili | DWH + DPO | Flag GDPR su ogni attributo |

### Fase 3 — Lineage e criticità (Mese 4-6)

| Attività | Chi | Output |
|---|---|---|
| Documentazione lineage flusso MGAlfa | Team DWH | Tracciabilità completa sorgente→QRT |
| Documentazione lineage flussi IVASS | Team DWH | Tracciabilità modelli 34-41 |
| Valutazione criticità per ogni entità | Data Owner + Risk | Matrice compilata |
| Attivazione workflow approvativi | Team DWH | Governance operativa |
| Prima review di data quality nel catalogo | Team DWH | Regole DQ censite |

### Fase 4 — Consolidamento (Mese 6-12)

| Attività | Chi | Output |
|---|---|---|
| Formazione utenti business | Team DWH | Utenti autonomi nella consultazione |
| Definizione policy di retention | Compliance + DPO | Periodi di conservazione formalizzati |
| Review periodica classificazioni | Data Owner | Processo ricorrente semestrale |
| Valutazione DLP e strumenti avanzati | IT | Roadmap tecnologica |
| Preparazione audit IVASS | DWH + Risk + Compliance | Documentazione pronta |

---

## 5. Risorse Necessarie

### Impegno del team DWH

| Fase | Effort stimato | Note |
|---|---|---|
| Fase 1 (fondazione) | ~15 giorni/persona | Concentrato su 1-2 persone. Non blocca l'operatività quotidiana |
| Fase 2 (classificazione) | ~20 giorni/persona | Distribuito su 2 mesi, coinvolge tutto il team |
| Fase 3 (lineage) | ~15 giorni/persona | Lavoro che migliora la documentazione esistente |
| Fase 4 (consolidamento) | ~5 giorni/persona | Manutenzione ordinaria |

**L'effort totale è di circa 55 giorni/persona distribuiti su 12 mesi**, pari a circa il
5% della capacità annua del team di 5 persone. Il lavoro di documentazione è in larga
parte un'attività che il team dovrebbe già svolgere ma che oggi non viene fatta per
mancanza di uno strumento adeguato.

### Cosa serve dal management

| Richiesta | Perché |
|---|---|
| **Nomina formale dei Data Owner** | Senza un responsabile per dominio dati, la governance non funziona |
| **Mandato al DPO** (o nomina se assente) | Obbligo GDPR, necessario per approvare trattamenti con dati sensibili |
| **Comunicazione alle funzioni business** | Il catalogo deve essere usato anche fuori dal team DWH |
| **Supporto IT infrastruttura** | Per proteggere le cartelle di rete e configurare ACL |

### Costi

| Voce | Costo |
|---|---|
| Licenze software | **Zero** (SQL Server già in uso, web app su Kestrel) |
| Hardware | **Zero** (stesso server DWH) |
| Consulenze esterne | **Zero** (realizzato internamente) |
| Effort interno | ~55 gg/persona su 12 mesi (costo opportunità, non costo vivo) |

---

## 6. Benefici Attesi

### Quantificabili

| Beneficio | Stima |
|---|---|
| Riduzione tempo di risposta ad audit IVASS/Garante | Da settimane a giorni |
| Riduzione tempo di onboarding nuove risorse DWH | Da mesi a settimane |
| Riduzione tempo di impact analysis per modifiche ETL | Da ore a minuti |
| Eliminazione rischio data loss su file non backuppati | Rischio oggi = alto, target = trascurabile |

### Strategici

- **Conformità GDPR dimostrabile** al Garante Privacy
- **Tracciabilità Solvency** documentata per IVASS
- **Riduzione rischio operativo** sulle alimentazioni critiche
- **Eliminazione shadow IT** con censimento e protezione dei file
- **Knowledge management** — il patrimonio dati diventa patrimonio aziendale, non delle singole persone
- **Fondazione per evoluzione futura** — il catalogo è la base per eventuale migrazione cloud, implementazione DLP, adozione di strumenti avanzati

---

## 7. Rischi del Progetto

| Rischio | Mitigazione |
|---|---|
| Il team DWH non ha tempo | L'effort è distribuito su 12 mesi (5% della capacità). Il catalogo riduce il lavoro futuro |
| I Data Owner non collaborano | Serve mandato del management. Il catalogo è utile anche per loro |
| Il catalogo non viene mantenuto aggiornato | Workflow obbligatorio per nuove entità. Review semestrale schedulata |
| Il progetto viene percepito come burocrazia | L'applicazione web rende il catalogo utile, non solo un obbligo |

---

## Conclusione

Il Governed Data Catalog è un investimento a costo zero in termini di licenze e
infrastruttura, con un effort contenuto e distribuito nel tempo. Non è un progetto
"nice to have": è la risposta strutturata a obblighi normativi concreti (GDPR, IVASS,
Solvency II) e a rischi operativi reali (shadow IT, data loss, tracciabilità).

**La domanda non è "possiamo permetterci di farlo?" ma "possiamo permetterci di non farlo?"**

---

*Documento preparato dalla Direzione Data Warehouse — Athora Italia S.p.A.*
*Febbraio 2026*
