# Guida GDPR per Athora Italia - Cosa Dovete Fare

## Premessa

Il GDPR (Regolamento UE 2016/679) si applica pienamente ad Athora Italia in quanto trattate
dati personali di persone fisiche (contraenti, assicurati, beneficiari, agenti, dipendenti).
Come compagnia assicurativa vita, trattate anche **categorie particolari di dati** (dati
sanitari ex Art. 9) che richiedono tutele rafforzate.

---

## 1. OBBLIGHI PRINCIPALI

### 1.1 Registro dei Trattamenti (Art. 30) - **OBBLIGATORIO**

Dovete tenere un registro scritto di tutte le attività di trattamento. Il catalogo che
abbiamo costruito include questo registro nella sezione `dcat.GdprProcessingActivity`.

**Contenuto obbligatorio per ogni trattamento:**
- Nome e dati di contatto del Titolare (Athora Italia S.p.A.)
- Finalità del trattamento
- Categorie di interessati (contraenti, assicurati, beneficiari...)
- Categorie di dati personali trattati
- Destinatari (SAP, MGAlfa, IVASS, Banca d'Italia...)
- Trasferimenti verso paesi terzi (se applicabile)
- Termini di cancellazione (retention)
- Descrizione delle misure di sicurezza

**I trattamenti che abbiamo pre-censito nel catalogo:**

| Codice | Trattamento | Base giuridica |
|---|---|---|
| POLICY_MGMT | Gestione polizze vita | Art. 6.1.b (contratto) |
| CLAIMS_MGMT | Gestione sinistri e liquidazioni | Art. 6.1.b (contratto) |
| ACCOUNTING | Contabilità e prima nota SAP | Art. 6.1.c (obbligo legale) |
| SOLVENCY | Valutazione solvibilità MGAlfa | Art. 6.1.c (obbligo legale) |
| REGULATORY_IVASS | Segnalazioni IVASS (mod. 34-41) | Art. 6.1.c (obbligo legale) |
| REGULATORY_BDI | Segnalazioni Banca d'Italia | Art. 6.1.c (obbligo legale) |
| AML | Antiriciclaggio | Art. 6.1.c (obbligo legale) |
| RISK_MGMT | Risk management e ORSA | Art. 6.1.f (legittimo interesse) |
| DWH_ANALYTICS | Data warehousing e analisi | Art. 6.1.f (legittimo interesse) |

### 1.2 Nomina DPO (Art. 37) - **OBBLIGATORIO per assicurazioni**

Le compagnie assicurative trattano dati su larga scala e dati sanitari, quindi la nomina
del DPO è obbligatoria. Se non avete ancora un DPO:
- Può essere interno o esterno
- Deve avere competenze in materia di protezione dati
- Deve essere indipendente (non può ricevere istruzioni sulle sue funzioni)
- I suoi dati di contatto vanno comunicati al Garante Privacy

### 1.3 DPIA - Valutazione d'Impatto (Art. 35)

Una DPIA è **obbligatoria** quando un trattamento presenta rischi elevati per i diritti
degli interessati. Per Athora Italia, è necessaria almeno per:

1. **Trattamento dati sanitari** (questionari medici, cause sinistro)
2. **Profilazione a fini assicurativi** (se effettuata)
3. **Trattamento su larga scala** di dati personali nel DWH
4. **Trasferimento dati a terzi** (MGAlfa/Milliman, SAP, eventuali outsourcer)

### 1.4 Informativa agli interessati (Art. 13-14)

Dovete informare tutti gli interessati su come trattate i loro dati. L'informativa deve
contenere: identità titolare, finalità, base giuridica, destinatari, retention, diritti.

### 1.5 Gestione dei diritti degli interessati (Art. 15-22)

Dovete essere in grado di rispondere entro 30 giorni a richieste di:
- **Accesso** (Art. 15): "Quali miei dati avete?"
- **Rettifica** (Art. 16): "Correggete il mio indirizzo"
- **Cancellazione** (Art. 17): "Cancellate i miei dati" (con limiti per obblighi legali)
- **Portabilità** (Art. 20): "Datemi i miei dati in formato strutturato"

> **NOTA per il DWH:** Il catalogo dati è fondamentale per rispondere a queste richieste,
> perché permette di sapere esattamente in quali tabelle/file risiedono i dati di un interessato.

---

## 2. CATEGORIE DI DATI PERSONALI TRATTATI DA ATHORA

### Dati personali "ordinari" (Art. 6)

| Categoria | Esempi | Dove risiedono |
|---|---|---|
| Identificativi | Codice fiscale, nome, cognome, data nascita | PASS, Smarthall, DWH Hub Soggetti |
| Contatto | Indirizzo, telefono, email | PASS, Smarthall, DWH Hub Soggetti |
| Finanziari | Premi pagati, importi liquidati, IBAN | DWH Hub Premi, Hub Liquidazioni |
| Contrattuali | N. polizza, ramo, rischio, stato, date | DWH Hub Polizze |
| Professionali | Codice agente, provvigioni | PASS, Smarthall |

### Categorie particolari (Art. 9) - **TUTELA RAFFORZATA**

| Categoria | Esempi | Dove risiedono |
|---|---|---|
| **Sanitari** | Questionari medici underwriting, cause decesso, patologie | PASS, Smarthall, potenzialmente DWH |
| Giudiziari | Procedimenti legali su sinistri | Eventualmente nel gestionale sinistri |

> **ATTENZIONE:** I dati sanitari richiedono:
> - Classificazione STRETTAMENTE RISERVATO
> - Crittografia obbligatoria (TDE)
> - Accesso solo su base need-to-know con approvazione DPO
> - DPIA obbligatoria
> - Pseudonimizzazione dove possibile

---

## 3. CATEGORIE DI INTERESSATI

| Categoria | Stima | Dati trattati |
|---|---|---|
| Contraenti | Da censire | Tutti i dati contrattuali, anagrafici, finanziari |
| Assicurati | Da censire | Anagrafici, sanitari (se diversi dal contraente) |
| Beneficiari | Da censire | Anagrafici, finanziari (liquidazioni) |
| Percipienti | Da censire | Anagrafici, finanziari, fiscali |
| Agenti/Intermediari | Da censire | Professionali, provvigionali |
| Residenti esteri | Da censire | Anagrafici + segnalazione BdI |
| Dipendenti | Da censire | Anagrafici, contrattuali lavoro |

---

## 4. RETENTION - PERIODI DI CONSERVAZIONE

Per una compagnia assicurativa vita in Italia:

| Tipo dato | Retention | Base normativa |
|---|---|---|
| Dati di polizza | 10 anni dalla cessazione | Art. 2220 CC + normativa assicurativa |
| Dati contabili | 10 anni | Art. 2220 Codice Civile |
| Dati sinistri | 10 anni dalla liquidazione | Prescrizione decennale |
| Dati antiriciclaggio | 10 anni dall'operazione | D.Lgs. 231/2007 Art. 31 |
| Dati segnalazioni IVASS | 10 anni | Normativa di vigilanza |
| Dati sanitari underwriting | Per durata polizza + 10 anni | Obbligo contrattuale + prescrizione |
| Dati marketing (se consenso) | Fino a revoca consenso | GDPR Art. 7 |

> **AZIONE NECESSARIA:** Implementare procedure automatizzate di cancellazione/anonimizzazione
> per i dati che superano il periodo di retention. Nel DWH questo significa:
> - Identificare record oltre la retention
> - Anonimizzare (non cancellare se servono a fini statistici)
> - Documentare l'operazione nell'audit log

---

## 5. MISURE DI SICUREZZA RACCOMANDATE

### Immediate (da fare subito)

1. **Proteggere i file su rete**: creare cartelle con ACL, rimuovere accesso "Everyone"
2. **Censire i file su PC locali**: identificare chi ha dati personali su PC
3. **Abilitare audit SQL Server**: tracciare chi accede a cosa
4. **Policy password**: complessità minima, scadenza, MFA dove possibile

### A breve termine (3-6 mesi)

1. **TDE (Transparent Data Encryption)** su SQL Server per i DB con dati sensibili
2. **Backup crittografati**: verificare che i backup siano crittografati
3. **Segmentazione accessi**: creare ruoli SQL Server allineati al principio del minimo privilegio
4. **Data masking**: implementare dynamic data masking per ambienti di sviluppo/test

### A medio termine (6-12 mesi)

1. **Microsoft Purview**: valutare per discovery automatica e classificazione
2. **DLP endpoint**: protezione contro l'esportazione non autorizzata di dati
3. **SIEM**: monitoraggio centralizzato degli accessi ai dati sensibili

---

## 6. PROCEDURA PER DATA BREACH (Art. 33-34)

In caso di violazione dei dati personali:

1. **Entro 72 ore**: notifica al Garante Privacy se c'è rischio per i diritti degli interessati
2. **Senza ritardo**: comunicazione agli interessati se il rischio è elevato
3. **Documentare**: registrare ogni violazione nell'audit log del catalogo

> **Il Data Catalog aiuta nella gestione dei breach** perché permette di:
> - Identificare rapidamente quali dati sono coinvolti
> - Risalire tramite il lineage a tutte le copie/derivazioni del dato violato
> - Identificare gli interessati coinvolti
> - Valutare l'impatto tramite la matrice di criticità

---

## 7. PROSSIMI PASSI PER ATHORA ITALIA

### Priorità 1 - Urgente
- [ ] Nominare/confermare il DPO
- [ ] Completare il registro trattamenti nel catalogo
- [ ] Censire e proteggere i file shadow IT
- [ ] Nominare i Data Owner per ogni sistema

### Priorità 2 - Importante
- [ ] Eseguire DPIA per i trattamenti con dati sanitari
- [ ] Implementare procedure di risposta ai diritti degli interessati
- [ ] Definire e implementare la retention policy nel DWH
- [ ] Formare il personale sui livelli di classificazione

### Priorità 3 - Consolidamento
- [ ] Implementare DLP
- [ ] Automatizzare la classificazione dei nuovi dati
- [ ] Review periodica del registro trattamenti
- [ ] Audit periodico della sicurezza dei dati
