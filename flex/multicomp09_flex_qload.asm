* QUICK FLEX LOADER UTILITY
*
* FROM 6809 FLEX ADAPTION GUIDE, APPENDIX D
*
* ADAPTED FOR MULTICOMP 6809
* QLOAD IS ONLY USED ONCE AS PART OF THE BOOTSTRAP OF A NEW
* SYSTEM. ITS PURPOSE IS TO LOAD IN A BINARY IMAGE OF THE CORE
* OS (FLEX.COR) SO THAT THE OS CAN BE STARTED. IT REQUIRES THAT
* THE TARGET-SPECIFIC DEVICE DRIVERS HAVE BEEN LOADED INTO MEMORY
* AT THE CORRECT LOCATION SO THAT THE FLEX.COR IMAGE CAN USE THEM.
* THE END RESULT IS A MEMORY-RESIDENT FULLY-FUNCTIONAL OS THAT CAN
* BE USED TO
* 1. SAVE THE DEVICE DRIVERS AS FILES ON THE DISK
* 2. APPEND THE DEVICE DRIVER FILES TO FLEX.COR TO CREATE FLEX.SYS
* 3. RUN THE "LINK" COMMAND TO PATCH THE LOCATION OF FLEX.SYS INTO
*    THE LOADER ON THE DISK'S BOOT SECTOR.
*
* THE ADAPTION GUIDE ASSUMES THAT FLEX.COR BEGINS ON TRACK=1, SECTOR=1
* BUT THAT IS NOT TRUE FOR THE SYSTEM DISK THAT I "CREATED" FOR THIS
* EXCERCISE. THAT IS NO PROBLEM AS THE LOCATION OF THE IMAGE IS DEFINED
* IN TWO BYTES AT THE START OF THE SOURCE FILE AND CAN TRIVIALLY BE
* MODIFIED TO THE CORRECT VALUE.
* THE CORRECT VALUE CAN BE DETERMINED BY INSPECTING THE .DSK FILE (EG
* USING "FLEXTRACT" OR "FLEX_DISK_MANIP") IN ORDER TO LOCATE THE START
* TRACK/SECTOR OF FLEX.COR.
* THE VALUES CODED BELOW ARE CORRECT FOR THE IMAGE I USED.
*
* QLOAD - QUICK LOADER
*
* COPYRIGHT (C) 1980 BY
* TECHNICAL SYSTEMS CONSULTANTS, INC.
* 111 PROVIDENCE RD. CHAPEL HILL, NC 27514
* LOADS FLEX FROM DISK ASSUMING THAT THE DISK I/O
* ROUTINES ARE ALREADY IN MEMORY. ASSUMES FLEX.COR
* BEGINS ON TRACK XX SECTOR YY (CODED BELOW). RETURNS TO
* MONITOR ON COMPLETION. BEGIN EXECUTION BY
* JUMPING TO LOCATION $C100
*

* MULTICOMP MEM_MAPPER2 CONTROL REGISTERS
* MMUADR (WRITE-ONLY)
* 7   - ROMDIS (RESET TO 0)
* 6   - TR
* 5   - MMUEN
* 4   - RESERVED
* 3:0 - MAPSEL
* MMUDAT (WRITE-ONLY)
* 7   - WRPROT
* 6:0 - PHYSICAL BLOCK FOR CURRENT MAPSEL

MMUADR         EQU $FFDE
MMUDAT         EQU $FFDF

* EQUATES
STACK           EQU  $C07F
MONITR          EQU  $D3F3
READ            EQU  $DE00
RESTORE         EQU  $DE09
DRIVE           EQU  $DE0C
SCTBUF          EQU  $C300      DATA SECTOR BUFFER

* START OF UTILITY
                ORG  $C100
QLOAD           BRA  INIMULT    INIT MULTICOMP ADDRESS MAP

                FCB 0,0,0
TRK             FCB 63          FILE START TRACK (BY INSPECTION OF DISK IMAGE)
SCT             FCB 03          FILE START SECTOR (BY INSPECTION OF DISK IMAGE)
DNS             FCB 0           DENSITY FLAG (NOT USED)
LADR            FDB 0           LOAD ADDRESS

LOAD0           LDS #STACK      SETUP STACK
                LDX #SCTBUF     POINT TO FCB
                CLR 3,X         MOCK UP FCB AS THO FOR DRIVE 0
                JSR DRIVE       SELECT DRIVE 0
                LDX #SCTBUF     X CORRUPTED BY THE CALL SO RELOAD
                JSR RESTORE     NOW RESTORE TO TRACK 0
                LDD TRK         SETUP STARTING TRK & SCT
                STD SCTBUF      MOCK UP LINK TO "NEXT" SECTOR
                LDY #SCTBUF+256 MOCK UP "ZERO BYTES LEFT"

* PERFORM ACTUAL FILE LOAD
* THIS ROUTINE PROCESSES ALL THE DATA UP TO THE END OF THE LAST SECTOR
* (SECTOR WITH LINK OF 0) SO ANY RUNT DATA BEYOND THE END OF THE FINAL
* RECORD MUST NOT CONTAIN $02 OR $16
LOAD1           BSR GETCH       GET A CHARACTER
                CMPA #$02       DATA RECORD HEADER?
                BEQ LOAD2       SKIP IF SO
                CMPA #$16       XFER ADDRESS HEADER?
                BNE LOAD1       LOOP IF NEITHER
                BSR GETCH       GET TRANSFER ADDRESS
                BSR GETCH       DISCARD IT
                BRA LOAD1       CONTINUE LOAD
LOAD2           BSR GETCH       GET LOAD ADDRESS
                STA LADR
                BSR GETCH
                STA LADR+1
                BSR GETCH       GET BYTE COUNT
                TFR A,B         PUT IN B (WAS "TAB" IN ORIGINAL
                TSTA            THIS EQUIVALENT FROM LEVENTHAL)
                BEQ LOAD1       LOOP IF COUNT=0
                LDX LADR        GET LOAD ADDRESS IN X
LOAD3           PSHS B,X
                BSR GETCH       GET A DATA CHARACTER
                PULS B,X
                STA 0,X+        PUT CHARACTER
                DECB            END OF DATA IN RECORD
                BNE LOAD3       LOOP IF NOT
                BRA LOAD1       GET ANOTHER RECORD

* GET CHARACTER ROUTINE - READS A SECTOR IF NECESSARY
GETCH           CMPY #SCTBUF+256 OUT OF DATA?
                BNE GETCH4      GO READ CHARACTER IF NOT
GETCH2          LDX #SCTBUF     POINT TO BUFFER
                LDD 0,X         GET FORWARD LINK
                BEQ GO          IF ZERO, FILE IS LOADED
                JSR READ        READ NEXT SECTOR
                BNE QLOAD       START OVER IF ERROR
                LDY #SCTBUF+4   POINT PAST LINK
GETCH4          LDA 0,Y+        ELSE, GET A CHARACTER
                RTS


* MULTICOMP SETUP
* INITIALISE AND ENABLE MEMORY MAPPER
* THEN DISABLE THE ROM SO THAT ADDRESS SPACE APPEARS AS RAM
INIMULT
                CLRA
                CLRB
                TFR A,DP        DEFAULT DP IN CASE WE CAME FROM CAMELFORTH
                LDX #16         16 MAPPING REGISTERS
MMUINIT         STD MMUADR      STORE 0000 0101 0202.. FOR FLAT MAPPING
                ADDD #$0101
                LEAX -1,X
                BNE MMUINIT
                LDA #$A0
                STA MMUADR      ENABLE MMU, DISABLE ROM: RAM APPEARS AT E000-FFFF
                BRA LOAD0       START THE LOADER

* FILE IS LOADED, RETURN TO MONITOR
GO              JMP $CD00       JUMP TO FLEX (WE HOPE..)

                END
