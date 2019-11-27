# DLS Auftragsdaten 

Die Javascript Anwendung dls.html kann nicht auf Netzlaufwerken ausgeführt werden, bei denen Active-X Steuerelemente deaktiviert sind.

D.h. dls.html auf lokaler Festplatte starten und Meldung 'Geblocke Inhalte zulassen' mit 'Ja' bestätigen. Dann zum Dekodieren des Inhaltes entsprechende CSV-Datei auswählen.  

## Aktualisierung
Erweiterung 2019-11-26 im Rahmen von Change 1576 (Track and Trace Russland)  
Script-Datei [dls_CHC-1576.html](dls_CHC-1576.html) - verwendete CSV-Datei [CHC1576_12606156_0116.csv](CHC1576_12606156_0116.csv)

### CSV-Datei Decodierung


| Spalte | Symbol                  | Definition
|--------|-------------------------|-------------------------------------------------------------
| 1      | OrderNo                 | AUFNR,CHAR12,PRAUF-Nr. für dascEtikett,VARCHAR,^[0-9]+$
| 2      | Factory                 | WERKS,CHAR4,Produktionswerk,VARCHAR,^DE13|DE09|DE53
| 3      | MaterialNo              | MATNR,CHAR18,Materialnummer Etikett,VARCHAR,^.+$
| 4      | MaterialText            | MATXT,CHAR40,Materialtext Etikett,VARCHAR,^.*$
| 5      | TotalCount              | MENG13,CHAR13,Menge Etiketten,INTEGER,^[0-9]+$
| 6      | Version                 | ZZDRUCKSTAND,CHAR4,Druckstand,VARCHAR,^.+$
| 7      | Lot                     | CHARG,CHAR10,Chargennummer,VARCHAR,^.*$
| 8      | CustomerLot             | CHARGENNUMMER_KUNDE,CHAR20,Kundencharge,VARCHAR,^.*$
| 9      | FormatManufacturingDate | FORMAT_HERSTELLDATUM,CHA10,Herstelldatum,VARCHAR,^.*$
|10      | FormatExpiryDate        | FORMAT_VERFALLSDATUM,CHAR10,Verfalldatum,VARCHAR,^.*$
|11      | LabelsPerReel           | MENG13,CHAR13,Anzahl Etiketten pro Rolle,INTEGER,^.*$
|12      | RawMaterial             | MATNR,CHAR18,Materialnummer Rohetikett,VARCHAR,^.+$
|13      | LabelType               | SOBSL,CHAR2,Druckausprägung,VARCHAR,^.+$
|14      | Pharmacode              | BBM_PHARMA_CODE,CHAR4,Pharma-/Laetuscode,VARCHAR,^.*$
|15      | EANCode                 | EAN11,CHAR18,EAN-Nr. Etikett,VARCHAR,^.*$
|16      | DataMatrixPrint         | DM,CHAR1,Ausprägung Data Matrix,INTEGER,^.*$
|17      | ManufacturingDate       | HSDAT,CHAR8,Herstelldatumfür DM,VARCHAR,^.*$
|18      | ExpiryDate              | VFDAT,CHAR8,VerfalldatumFür DM,VARCHAR,^.*$
|19      | PackingOrder            | ZZ_LINKORD,CHAR12,PRAUF-Nr. für Verpackung,VARCHAR,^.*$
|20      | RegulatoryUnit          | REGUNIT,CHAR4,Regulatorische Mengeneinheit,VARCHAR,^10|20|30|40|50|na$
|21      | TrackAndTraceRelevance  | xxxx,CHAR4,Track and Trace Relevanz,VARCHAR,^[0-3]{1}$  
|22      | AI_NHRN                 | ???  
|23      | NHRN                    | ???  
|24      | AlternativeRawMaterial  | ???    
|25      | LayoutRotation          | ???  
