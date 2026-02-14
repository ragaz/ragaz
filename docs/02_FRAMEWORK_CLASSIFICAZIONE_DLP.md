# Framework di Classificazione Dati e DLP

## Athora Italia S.p.A.

### 1. I 4 Livelli di Classificazione

Il framework definisce 4 livelli di classificazione crescente, ognuno con regole operative
specifiche per trattamento, archiviazione, trasmissione e distruzione.

---

#### PUBBLICO (Livello 1)

**Definizione:** Dati destinati o adatti alla divulgazione pubblica.

| Aspetto | Regola |
|---|---|
| **Esempi** | Bilancio pubblicato, comunicati stampa, informativa precontrattuale pubblica |
| **Storage** | Qualsiasi supporto |
| **Trasmissione** | Libera |
| **Accesso** | Nessuna restrizione |
| **Distruzione** | Nessuna procedura speciale |

---

#### INTERNO (Livello 2)

**Definizione:** Dati ad uso interno la cui divulgazione esterna non è autorizzata.

| Aspetto | Regola |
|---|---|
| **Esempi** | Procedure operative, comunicazioni interne, reportistica gestionale non sensibile |
| **Storage** | Solo sistemi aziendali (file server, SQL Server, SharePoint). Mai su dispositivi personali non gestiti |
| **Trasmissione** | Libera internamente. Esterna solo su canali sicuri previa autorizzazione |
| **Accesso** | Tutti i dipendenti con credenziali aziendali |
| **Distruzione** | Cancellazione standard |

---

#### RISERVATO (Livello 3)

**Definizione:** Dati personali (GDPR Art. 6), finanziari, contrattuali.
Accesso limitato al personale autorizzato.

| Aspetto | Regola |
|---|---|
| **Esempi** | Anagrafiche clienti (CF, nome, indirizzo), dati polizze, premi, liquidazioni, dati contabili, codici agenti |
| **Storage** | Sistemi protetti con accesso controllato. Crittografia a riposo raccomandata. **Vietato su cartelle di rete aperte** |
| **Trasmissione** | Solo canali crittografati. Email con allegati crittografati o portale sicuro |
| **Accesso** | RBAC (Role-Based Access Control). Autorizzazione esplicita del Data Owner. Review semestrale |
| **Distruzione** | Cancellazione sicura (sovrascrittura). Supporti fisici: distruzione certificata |
| **DQ** | Controlli di completezza e accuratezza obbligatori |

> **AZIONE IMMEDIATA per Athora:** Tutti i file Excel/CSV/Access su cartelle di rete aperte
> contenenti dati di questo livello devono essere migrati su aree protette con ACL.

---

#### STRETTAMENTE RISERVATO (Livello 4)

**Definizione:** Dati di categorie particolari ex Art. 9 GDPR (sanitari, giudiziari),
segreti industriali, dati la cui divulgazione causerebbe danno grave.

| Aspetto | Regola |
|---|---|
| **Esempi** | Questionari medici underwriting, cause morte sinistri, dati giudiziari, modelli attuariali proprietari, parametri SCR |
| **Storage** | Sistemi dedicati con crittografia obbligatoria (TDE su SQL Server). MFA per accesso |
| **Trasmissione** | Solo canali crittografati end-to-end. Pseudonimizzazione obbligatoria dove possibile |
| **Accesso** | Nominativo, approvato da Data Owner + DPO. Review trimestrale. Logging completo |
| **Distruzione** | Cancellazione certificata (standard DoD 5220.22-M). Audit trail di distruzione conservato 10 anni |
| **DQ** | Controlli bloccanti. Alert immediato in caso di anomalie |

---

### 2. Matrice di Classificazione per Sistema Athora

| Sistema | Classificazione base | Motivazione |
|---|---|---|
| PASS (ODS) | RISERVATO | Contiene anagrafiche, dati polizze, CF |
| PASS (flussi) | RISERVATO | Snapshot polizze con dati personali |
| Smarthall (flussi) | RISERVATO | Stessa tipologia di PASS |
| DWH Staging | RISERVATO | Replica fedele dei sorgenti |
| DWH Level 0 | RISERVATO | Formattazione, stessi dati |
| DWH Level 1 (Hub) | RISERVATO | Armonizzazione, potenzialmente dati sanitari → allora STRETT. RISERVATO |
| Input MGAlfa | STRETT. RISERVATO | Dati aggregati per Solvency, parametri riservati |
| Output SAP | RISERVATO | Dati contabili |
| File rete non protetti | RISERVATO (da governare) | **RISCHIO: attualmente senza protezione** |
| File PC locali | STRETT. RISERVATO (da censire) | **RISCHIO MASSIMO: nessun backup, nessun controllo** |

---

### 3. Piano di Azione Prioritario

#### Fase 1 - Immediata (0-3 mesi)
1. **Censimento file shadow IT**: scansione cartelle di rete per identificare tutti i file Excel/CSV/Access
2. **Classificazione urgente**: assegnare livello di classificazione a ogni file censito
3. **Protezione cartelle**: creare aree protette con ACL e migrare i file riservati
4. **Nomina Data Owner**: assegnare formalmente un Data Owner per ogni sistema sorgente

#### Fase 2 - Breve termine (3-6 mesi)
1. **Abilitare TDE** su SQL Server per i database con dati strettamente riservati
2. **Implementare audit degli accessi** ai database del DWH
3. **Definire policy di retention** e implementare procedure di cancellazione
4. **Formazione** del personale sui livelli di classificazione

#### Fase 3 - Medio termine (6-12 mesi)
1. **Valutare Microsoft Purview** o altro strumento DLP per monitoraggio automatico
2. **Automatizzare la classificazione** dei nuovi dati tramite il catalogo
3. **Review periodiche** della classificazione (semestrale)

---

### 4. Cos'è il "Shadow IT"

> **Shadow IT** indica tutti i sistemi informativi, applicazioni, file e processi che vengono
> utilizzati all'interno dell'azienda **al di fuori del perimetro governato dall'IT**.
>
> Nel vostro caso specifico, sono:
> - File Excel su cartelle di rete non protette usati per elaborazioni critiche
> - Database Access su PC locali con dati estratti dai gestionali
> - File CSV copiati dai flussi e salvati localmente
> - Qualsiasi foglio di calcolo che contiene dati personali o finanziari e che non è
>   censito, versionato, protetto da accesso e sottoposto a backup
>
> **Perché è un rischio:**
> - Nessun controllo di accesso (chiunque accede alla cartella vede tutto)
> - Nessun backup (se il PC si guasta, i dati sono persi)
> - Nessuna tracciabilità (chi ha modificato cosa e quando)
> - Violazione GDPR (dati personali senza misure di sicurezza adeguate)
> - Rischio per audit IVASS (dati regolamentari su supporti non governati)
