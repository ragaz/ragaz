# Matrice di Criticità - Modello di Valutazione

## Dimensioni di Impatto

Ogni entità dati viene valutata su 6 dimensioni con scala 1-5.

### Scala di valutazione

| Score | Significato |
|---|---|
| 1 | Trascurabile - Nessun impatto significativo |
| 2 | Basso - Impatto minimo e gestibile |
| 3 | Medio - Impatto significativo ma contenibile |
| 4 | Alto - Impatto grave che richiede intervento immediato |
| 5 | Critico - Impatto devastante, rischio di sanzioni/perdite gravi |

### Dimensioni

| Dimensione | Cosa misura | Score 5 = |
|---|---|---|
| **Regolamentare** | Impatto su segnalazioni obbligatorie | Errore su QRT Solvency o modelli IVASS = sanzione IVASS |
| **Operativo** | Impatto sulle operazioni quotidiane | Blocco completo delle operazioni (emissioni, liquidazioni) |
| **Finanziario** | Impatto economico diretto | Perdita finanziaria > 1M EUR o errore materiale di bilancio |
| **Reputazionale** | Danno di immagine | Notizia pubblica, perdita fiducia clienti/regolatore |
| **GDPR** | Rischio per dati personali | Data breach su dati sanitari di migliaia di assicurati |
| **Data Loss** | Rischio di perdita irrecuperabile | Dato non ricostruibile, unica copia su supporto non backuppato |

### Livelli risultanti

| Score totale (su 30) | Livello | Azione richiesta |
|---|---|---|
| >= 24 | **CRITICAL** | Monitoraggio continuo, alert automatici, DR plan dedicato |
| >= 18 | **HIGH** | Controlli DQ bloccanti, backup frequenti, owner dedicato |
| >= 12 | **MEDIUM** | Controlli DQ standard, monitoraggio periodico |
| < 12 | **LOW** | Controlli base |

## Valutazione preliminare per le entità Athora

| Entità | Reg. | Op. | Fin. | Rep. | GDPR | DL | Tot | Livello |
|---|---|---|---|---|---|---|---|---|
| Hub Polizze (L1) | 5 | 5 | 4 | 4 | 4 | 3 | **25** | CRITICAL |
| Hub Soggetti (L1) | 4 | 4 | 3 | 4 | 5 | 3 | **23** | HIGH |
| Hub Premi (L1) | 5 | 4 | 5 | 3 | 2 | 3 | **22** | HIGH |
| Hub Liquidazioni (L1) | 5 | 4 | 5 | 4 | 4 | 3 | **25** | CRITICAL |
| Hub Ruoli Polizza (L1) | 4 | 3 | 2 | 3 | 5 | 3 | **20** | HIGH |
| Input MGAlfa | 5 | 3 | 5 | 5 | 3 | 4 | **25** | CRITICAL |
| File Prima Nota SAP | 4 | 4 | 5 | 3 | 2 | 3 | **21** | HIGH |
| File rete non protetti | 2 | 2 | 2 | 3 | 4 | 5 | **18** | HIGH |
| File PC locali | 1 | 2 | 2 | 3 | 4 | 5 | **17** | MEDIUM |

### Focus: Flusso MGAlfa (Solvency II)

Questo è il flusso più critico perché:
- Alimenta il calcolo delle riserve tecniche (BEL, Risk Margin)
- Un errore nei dati di input produce errori nei QRT
- I QRT errati possono portare a sanzioni IVASS e requisiti di capitale errati
- Il dato viene assemblato da due gestionali diversi (PASS + Smarthall) → rischio di disallineamento
- I controlli DQ di primo livello sono l'unico presidio prima del trasferimento

**Raccomandazioni specifiche:**
- Controlli DQ bloccanti (severity = BLOCKER) su questo flusso
- Riconciliazione incrociata con ODS obbligatoria prima dell'invio
- Alert immediato al responsabile in caso di anomalie
- Documentare nel catalogo ogni regola DQ applicata
