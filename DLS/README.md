# DLS Auftragsdaten 

Die Javascript Anwendung dls.html kann nicht auf Netzlaufwerken ausgeführt werden, bei denen Active-X Steuerelemente deaktiviert sind.

D.h. dls.html auf lokaler Festplatte starten und Meldung 'Geblocke Inhalte zulassen' mit 'Ja' bestätigen. Dann zum Dekodieren des Inhaltes entsprechende CSV-Datei auswählen.  

## Aktualisierung
Erweiterung 2019-11-26 im Rahmen von Change 1576 (Track and Trace Russland)  
Script-Datei [dls_CHC-1576.html](dls_CHC-1576.html) - verwendete CSV-Datei [CHC1576_12606156_0116.csv](CHC1576_12606156_0116.csv)

### CSV-Datei Decodierung


| Spalte | Symbol                  | Definition
|--------|-------------------------|-------------------------------------------------------------
| 1      | PrintOrderNumber        | AUFNR,CHAR12,PRAUF-Nr. für dascEtikett,VARCHAR,^[0-9]+$
| 2      | Plant                   | WERKS,CHAR4,Produktionswerk,VARCHAR,^DE13|DE09|DE53
| 3      | MaterialNumber          | MATNR,CHAR18,Materialnummer Etikett,VARCHAR,^.+$
| 4      | MaterialText            | MATXT,CHAR40,Materialtext Etikett,VARCHAR,^.*$
| 5      | TotalCount              | MENG13,CHAR13,Menge Etiketten,INTEGER,^[0-9]+$
| 6      | PrintStamp              | ZZDRUCKSTAND,CHAR4,Druckstand,VARCHAR,^.+$
| 7      | Batch                   | CHARG,CHAR10,Chargennummer,VARCHAR,^.*$
| 8      | CustomerBatch           | CHARGENNUMMER_KUNDE,CHAR20,Kundencharge,VARCHAR,^.*$
| 9      | ManufacturingDate       | FORMAT_HERSTELLDATUM,CHA10,Herstelldatum,VARCHAR,^.*$
|10      | ExpiryDate              | FORMAT_VERFALLSDATUM,CHAR10,Verfalldatum,VARCHAR,^.*$
|11      | LabelsPerReel           | MENG13,CHAR13,Anzahl Etiketten pro Rolle,INTEGER,^.*$
|12      | RawMaterial             | MATNR,CHAR18,Materialnummer Rohetikett,VARCHAR,^.+$
|13      | SpecialProcurementKey   | SOBSL,CHAR2,Druckausprägung,VARCHAR,^.+$
|14      | Pharmacode              | BBM_PHARMA_CODE,CHAR4,Pharma-/Laetuscode,VARCHAR,^.*$
|15      | GTIN_NTIN               | EAN11,CHAR18,EAN-Nr. Etikett,VARCHAR,^.*$
|16      | DM_Line                 | DM,CHAR1,Ausprägung Data Matrix,INTEGER,^.*$
|17      | ManufacturingDateCode   | HSDAT,CHAR8,Herstelldatumfür DM,VARCHAR,^.*$
|18      | ExpiryDateCode          | VFDAT,CHAR8,VerfalldatumFür DM,VARCHAR,^.*$
|19      | PackingOrder            | ZZ_LINKORD,CHAR12,PRAUF-Nr. für Verpackung,VARCHAR,^.*$
|20      | RegulatoryUnit          | REGUNIT,CHAR4,Regulatorische Mengeneinheit,VARCHAR,^10|20|30|40|50|na$
|21      | TnT_Relevance           | TnT_Auspr,CHAR1,21. TnT-Relevance,VARCHAR,^.*$  
|22      | AI_NHRN                 | AI_for_NHRN,CHAR3,22. ApplicationIdentifier for NHRN,VARCHAR,^.*$
|23      | NHRN                    | NHRN,CHAR16,23. National HealthcareReimbursement Number,VARCHAR,^.*$
|24      | AlternativeRawMaterial  | AMATNR,CHAR18,24. AlternativeRawmaterial,VARCHAR,^.*$
|25      | LayoutRotation          | Rotation,CHAR3,25. Rotation,VARCHAR,^.*$
