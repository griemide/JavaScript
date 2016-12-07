

        #**************************************************************
        #**    Program/Module: serials
        #**
        #--------------------------------------------------------------
        #   Program written by:
        #     Franz Vater
        #--------------------------------------------------------------
        #** Copyright:
        #**  vimacon GmbH  (vimacon.com)
        #**  Langgasse 73
        #**  D-64409 Messel
        #
        #**  Owner:
        #**  CSAT GmbH
        #**  Daimlerstr.
        #**  Eggenstein-Leopoldshafen
        #**
        #** All rights reserved.
        #        
        # The content, organization, gathering, compilation, magnetic
        # translation, digital conversion and other matters related to
        # this program are protected under applicable copyrights, 
        # trademarks, and other proprietary (including, but not limited
        # to, intellectual property) rights, and, the copying, 
        # redistribution, use or publication of any such content or any
        # part of this file is prohibited except with prior written 
        # permission of CSAT.
        #
        # No part of any data may be reproduced in any form, including,
        # but not limited to by copies, microfilm, xerography, 
        # digitally, or incorporated into any information retrieval 
        # system, electronic or mechanical.
        #
        # Nobody may modify, reverse-engineer, disassemble, decompile,
        # translate or reduce the program to a human perceivable form.
        #
        #**************************************************************
        
        #**Revision History:
        
        #** 2011-09-16 : First Version 
        #** 2015-04-10 : Processing modified for BBraun Track&Trace
        #**              Serial DBs now bound to the jobs rather
        #**              than to eancode

        #**************************************************************



# ---------------------------------------------------------------------
# Module Description
# ---------------------------------------------------------------------

# this module contains the handling of serial numbers


# ---------------------------------------------------------------------
# Preset System Variables While Loading
# ---------------------------------------------------------------------

##
# Namespace for serial number administration features 

namespace eval ::Serials {
   variable my
}


# ---------------------------------------------------------------------
# Local Procedure Definitions
# ---------------------------------------------------------------------


#----------------------------------------------------------------------
##
# Init the serial number handling
#
#----------------------------------------------------------------------

proc ::Serials::Init {} \
{
   variable my
   global  env

   set workbase $::options(WorkFolder)

   # init serials database folder


   set ::options(SerialsFolder)           [GetConfig SerialsFolder            [GetOption SerialsFolder         ""]]
   set ::options(SerialsImportFolder)     [GetConfig SerialsImportFolder      [GetOption SerialsImportFolder   ""]]

   set ::options(SupportSerials)          [string equal -nocase [string trim [GetConfig SupportSerials           [GetOption SupportSerials       "no" ]]]    "yes"]
   set ::options(SupportSerialsImport)    [string equal -nocase [string trim [GetConfig SupportSerialsImport     [GetOption SupportSerialsImport "no" ]]]    "yes"]

   set ::options(SupportSerialsGenerator) [string equal -nocase [string trim [GetConfig SupportSerialsGenerator  [GetOption SupportSerialsGenerator "no" ]]] "yes"]

   if {$::options(SupportSerials)} \
   {
      if {[string equal $::options(SerialsFolder) ""]} \
      {
         # no folder config
         ErrorAckDialog [subst $::txt(dlg_NoSerialsFolderGiven)]
         exit 1
      } \
      else \
      {
         set serialsfolder [file join $::options(SerialsFolder)]
         if { ! [file exists $serialsfolder]} \
         {
            # folder missing
            ErrorAckDialog [subst $::txt(dlg_NoSerialsFolder)]
            exit 1
         }
      }
   }


   if {$::options(SupportSerialsImport)} \
   {
      if {[string equal $::options(SerialsImportFolder) ""]} \
      {
         # no folder config
         ErrorAckDialog [subst $::txt(dlg_NoSerialsImportFolderGiven)]
         exit 1
      } \
      else \
      {
         set serialsimportfolder [file join $::options(SerialsImportFolder)]
         if { ! [file exists $serialsimportfolder]} \
         {
            # folder missing
            ErrorAckDialog [subst $::txt(dlg_NoSerialsImportFolder)]
            exit 1
         }
      }
   }


   set ::options(ComponentResults) [list "S1" CAPS "S2" HMI "S3" Camera1 "S4" Camera2 "S5" Codereader1]

   return 0      
}



#----------------------------------------------------------------------
#**
#**  Return symbolic state for numeric state
#**
#** in    : num = numeric part state 
#**
#** out   : --
#**
#** global: ::partstates
#**
#** return: state text, "" if number is unknown
#**
#----------------------------------------------------------------------

proc SymbolicPartState {num} {
   if {[info exists ::partstates(S,$num)]} {
      return $::partstates(S,$num)
   } else {
      return ""
   }
}


#----------------------------------------------------------------------
#**
#**  Return numeric state for symbolic state
#**
#** in    : sym = symbolic part state 
#**
#** out   : --
#**
#** global: ::partstates
#**
#** return: number, -1 if symbol is unknown 
#**
#----------------------------------------------------------------------

proc NumericPartState {sym} {

   if {[info exists ::partstates(N,$sym)]} {
      return $::partstates(N,$sym)
   } else {
      return -1
   }
}

#----------------------------------------------------------------------
##
# Initialize part state control
#----------------------------------------------------------------------

proc InitPartStates {} {
   global env
   variable my

#   DEBUG "InitPartStates"    
 
   set ::partstates(List) [list  1 Created 2 Aborted 3 Finished]

   # init helper variables
   
   foreach {n cs} $::partstates(List) {
      set ::partstates(N,$cs) $n   ;# numeric state
      set ::partstates(S,$n)  $cs  ;# symbolic name of numeric state
   }
   return 0
}

#----------------------------------------------------------------------
##
# Return the next free serial for this job if printed on "printer"
# and the estimated last serial
#
# @param jobid Job ID
# @param printer Numeric printer id
# @param tg      Target array variable
#
# @return 0 if success \n
#         1 error with DB access \n
#         2 if no such job in DB  \n
#         4 if job already in serial db \n
#         5 if a part is still open \n
#         
#----------------------------------------------------------------------

proc ::Serials::GetNext {jobid printer tg} {
   variable my
   global  env
   
   upvar $tg target
   
   set target(First)        -1
   set target(LastSheduled) -1

#   DEBUG "::Serials::GetNext jobid=$jobid --- printer=$printer "

   # get some key data about job to find out how to handle serial numbers
   
   set sql "SELECT JobID, Lot, TotalCount, OrderNo, Factory, MaterialNo, Version, CustomerLot, PackingOrder, JobStatus FROM printjobs WHERE JobID LIKE '$jobid';" 

   if {[catch {set joblist [::Jobs::SaveExecSQL $sql]} errmsg]} {
      ERROR $errmsg
      return 1
   }

#   DEBUG "joblist=$joblist"

   if {[llength $joblist] == 0} {
      # no job with this jobid found
      return 2
   }

   set lot       [lindex $joblist 1]
   set count     [lindex $joblist 2]
   set jobstatus [lindex $joblist 9]
   
   if {($jobstatus == [NumericJobState "JobReleased"]) || ($jobstatus == [NumericJobState "JobReleasedForReprint"]) || ($jobstatus == [NumericJobState "ReadyForPrintProceed"])} {
      # ok. fine
   } else {
      # error: job not in a state to be assigned to a printer
      
      ERROR "Job \"$jobid\" not assignable to a printer"
      return 4
   } 

   # read jobticket for reference data
   set jobfolder [file join $::options(JobFolder) $jobid]
   set jobticketfile [file join $jobfolder  $jobid.ini]
   ::Ini::ReadFile $jobticketfile "utf-8" jobdata ".*" -notrim
   set numberOfSubJobs [::Ini::GetValue jobdata DLS.Results "NumberOfSubJobs" "0"] 

   if {1} {
      # set defaults
   
      set start 1
      
      # get a list of all parts of this job

      set sql "SELECT JobID, Lot, PartID, Printer, PartStatus, FirstDate, FirstPrinted, LastDate, LastSheduled, LastPrinted, AmountSheduled, AmountPrinted, FinalJobStatus, TargetReels, PrintedReels, FirstReel FROM parts WHERE JobID LIKE '$jobid' ORDER BY PartID;" 

      if {[catch {set jobslist [::Jobs::SaveExecSQL $sql]} errmsg]} {
         ERROR $errmsg
         return 1
      }

      if {[llength $jobslist] == 0} {
         # no entry for this job until now
         set printed   0
         set start     1
         set partid 1     
         set sheduledend    $count
         set amountsheduled $count
         set targetReels    $numberOfSubJobs
         set printedReels   0
         set firstReel      1
      } else {
         # seems to be printed before
         
         set printed   0
         set start     1
         set partid    1     
         set targetReels    $numberOfSubJobs
         set printedReels   0
         set firstReel      1
         
         set finstate   [NumericPartState "Finished"] ;# PartState if this part was used
         set abortstate [NumericPartState "Aborted"]  ;# PartState if this part was not used

         foreach {JobID Lot PartID Printer PartStatus FirstDate FirstPrinted LastDate LastSheduled LastPrinted AmountSheduled AmountPrinted FinalJobStatus TargetReels PrintedReels FirstReel} $jobslist {
            # add number of printed labels (same job)

#           DEBUG "::Serials::GetNext  JobID=$JobID --- partid=$partid --- Lot=$Lot"

            if {[string equal $JobID $jobid]} {
               incr partid

               if {[string equal $PartStatus $finstate]} {
                  set printed      [expr {$printed   + $AmountPrinted}]
                  set firstReel    [expr {$firstReel + $PrintedReels}]
               } elseif {[string equal $PartStatus $abortstate]} {
                  # part discarded, ignore amount
               } else {
                  # oops. open part found
                  return 5
               }
            }    

            # check last printed serial if any (same lot + same printer)
            
            if {[string equal $Printer $printer]} {
               if { ! [string equal $LastPrinted ""]} {
                  if {$LastPrinted > $start} {
                     set start $LastPrinted
                  }
               }   
   
               # check also last scheduled serial if any
                
               if { ! [string equal $LastSheduled ""]} {
                  if {$LastSheduled > $start} {
                     set start $LastSheduled
                  }
               }   
            }
         }

         if {$start > 1} {
            # add extra safety margin
            set start [expr {$start + [::Ini::GetValue ::iniconfig "DLS.Serials" "ExtraMargin" "100"] }]      
         }
         
         set sheduledend    [expr {$start + $count - $printed - 1}]
         set amountsheduled [expr {$count - $printed}]
      }
            
      # build new start and sheduled end numbers
      
      set free1 "0"
      set free2 "0"
      
      set start_formatted [format "%s%1s%1s%1s%07d" $lot $free1 $free2 $printer $start]
      set end_formatted   [format "%s%1s%1s%1s%07d" $lot $free1 $free2 $printer $sheduledend]

      # update database
      
      set sql "INSERT INTO parts (JobID,     Lot,    PartID,    Printer,   PartStatus,                    FirstDate,        FirstPrinted, LastDate, LastSheduled,   LastPrinted, AmountSheduled,    AmountPrinted,  TargetReels,    PrintedReels,    FirstReel,    FinalJobStatus) VALUES \ 
                                 ('$jobid', '$lot', '$partid', '$printer', '[NumericPartState Created]', '[clock seconds]', '$start',     '',       '$sheduledend', '',         '$amountsheduled', '0',             '$targetReels', '$printedReels', '$firstReel', '[NumericJobState ReservedByPrinter]' ) ; \n"

      if {[catch {::Jobs::SaveExecSQL $sql} errmsg]} {
         ERROR $errmsg
         return 1
      }

      # return values to caller via target array

      set target(First)              $start_formatted
      set target(LastSheduled)       $end_formatted

      set target(FirstNumber)        $start
      set target(LastSheduledNumber) $sheduledend

      set target(PrinterID)          $printer
      
      set target(AmountSheduled)     $amountsheduled
      set target(PartID)             $partid
      
      set target(TargetReels)        $targetReels
      set target(PrintedReels)       $printedReels
      set target(FirstReel)          $firstReel
   }
   
   # update job status
   
   set setstate [NumericJobState ReservedByPrinter]

   if {[catch {::Jobs::SetJobState $jobid $setstate} errmsg]} {
      ERROR $errmsg
      SystemErrorDialog $errmsg
      return 1
   }

#   LogJobAction "ReservedByPrinter" $jobid  ;# geht zur Zeit nicht weil z.B. ::user(FullName) nicht gesetzt ist (threading)

   return 0  ;# no error
}


#----------------------------------------------------------------------
##
# Mark the job as started by registering the "FirstDate" field
#
# @param jobid Job ID
# @param firstdate Timestamp of first date of printing
#
# @return 0 if success, !=0 otherwise 
#         
#----------------------------------------------------------------------

proc ::Serials::MarkStarted {jobid firstdate} {
   variable my
   global  env

}


#----------------------------------------------------------------------
##
# Set the data fields "LastDate" and "LastPrinted"
#
# @param jobid       Job ID
# @param lastdate    Timestamp of last print date
# @param lastprinted Serial number last printed
#
# @return 0 if success, !=0 otherwise 
#         
#----------------------------------------------------------------------

proc ::Serials::RegisterFinished {jobid lastdate lastprinted} {
   variable my
   global  env

}


#----------------------------------------------------------------------
##
# The job was not printed on this printer at all and the serial
# number range shall be freed again
#
# @param jobid       Job ID
#         
#----------------------------------------------------------------------

proc ::Serials::Free {jobid} {
   variable my
   global  env

}

#----------------------------------------------------------------------
##
# Check whether serials DB exists
#
# @param jobid       Job ID
#         
#----------------------------------------------------------------------

proc ::Serials::DBExists {jobid} {

   set tgname [file join $::options(JobFolder) $jobid serials.sqlite]

   return [file exists $tgname]

}

#----------------------------------------------------------------------
##
# Return number of available serial for this jobid
#
# @param jobid       Job ID
#         
#----------------------------------------------------------------------

proc ::Serials::AvailableNumbers {jobid} {
   variable my
   global  env

   if { ! [::Serials::DBExists $jobid]} {
#     AckDialog "::Serials::AvailableNumbers jobid=$jobid --- DB EXISTIERT NICHT"
      return 0  ;# does not exist at all
   }
   
   set sql "SELECT COUNT(id) FROM serials WHERE State = '1';"
   
   return [::Serials::SaveExecSQL $jobid $sql]
}



#----------------------------------------------------------------------
#** proc   ::Serials::SerialsDBFilename {jobid}
#**
#** Return the name of the DB file for a given jobid
#**
#** in    : jobid  = database id
#**
#** out   : --
#**
#** global: --
#**
#** return: --
#**         
#----------------------------------------------------------------------

proc ::Serials::SerialsDBFilename {jobid} {
   return [file join $::options(JobFolder) $jobid serials.sqlite]
}


#----------------------------------------------------------------------
#** proc   ::Serials::ReleaseSerials {jobid interactive}
#**
#** Release the serial numbers of the given job if any and if possible
#**
#** in    : jobid       = job id
#**         interactive 0=background, 1=operator attended processing
#**
#** out   : --
#**
#** global: --
#**
#** return: --
#**         
#----------------------------------------------------------------------

proc ::Serials::ReleaseSerials {jobid interactive} {
   variable my
   global  env


   set jf     [file join $::options(JobFolder) $jobid]
   set jobini [file join $jf $jobid.\ini]
   
   ::Ini::ReadFile $jobini "utf-8" jobdata ".*" -notrim    ;# read jobticket
   
   set kind    [::Ini::GetValue jobdata DLS.Serials Kind  ""]

   set eancode        [::Ini::GetValue jobdata JobData  EANCode  ""]            ;# optionally padded
   set trackAndTrace  [string equal -nocase [::Ini::GetValue jobdata DLS.Serials  TrackAndTrace        "no"] "yes"]

   # release serials
   
   set sql "UPDATE serials SET State='1' WHERE State LIKE '%';"

   if {[catch {::Serials::SaveExecSQL $jobid $sql} errmsg]} {
      ERROR "DB error: $errmsg"
      ErrorAckDialog $errmsg
      return 1
   }

   return 0
}


#----------------------------------------------------------------------
#** proc   ::Serials::PadSerial {serial len}
#**
#** Pad serial number with leading 0 if $len > length of $serial
#**
#** in    : serial = serial (number) string
#**         len    = target length, defined by number of p chars
#**
#** out   : --
#**
#** global: --
#**
#** return: formatted string
#**         
#----------------------------------------------------------------------

proc ::Serials::PadSerial {serial len} {
  
   # fill with leading 0 if less than "len" characters

   set seriallen [string length $serial]

   if { $seriallen < $len} {
      set pad [expr {$len - $seriallen}]

      set formatSerial ""
      
      for {set i 1} {$i <= $pad} {incr i} {
         append formatSerial "0"
      }
      
      append formatSerial $serial
   } else {
      return $serial ;# if length = 0, too long or exactly correct length
   }
   
   return $formatSerial
}


#----------------------------------------------------------------------
##
# Build one or more reel ticket files according to configuration
#
# @param jobid  Job ID
#
# @return Status: 0 = ok
#

         
proc ::Serials::GenerateReelTickets {jobid} {
   variable my
   global  env

   set jobini [file join $::options(JobFolder) $jobid $jobid.\ini]
   
   ::Ini::ReadFile $jobini "utf-8" jobdata ".*" -notrim

#   DEBUG "::Serials::GenerateSerialFiles: jobid=$jobid"

   # check whether jobticket was read
   if {[string equal [::Ini::GetValue jobdata JobSource  JobID ""] ""]} {
      set ticketfile $jobini  ;# for dialog
      SystemErrorDialog   [subst $::txt(err_CannotReadTicket)]
      return 1
   }

   set excessPerReel  [string equal -nocase [::Ini::GetValue jobdata DLS.Serials  ExcessLabelsPerReel  "no"] "yes"]
   set makeReelJobs   [string equal -nocase [::Ini::GetValue ::iniconfig DLS.Jobs SubJobsPerReel       "no"] "yes"]
   set totalLabels    [::Ini::GetValue jobdata DLS.Serials TotalCount.Input      0]
   set extraTotal     [::Ini::GetValue jobdata DLS.Serials ExtraMargin           0]
   set extraFirstReel [::Ini::GetValue jobdata DLS.Serials ExtraMargin.FirstReel 0]
   set labelsPerReel  [::Ini::GetValue jobdata JobData LabelsPerReel             5000]
   
   # variables for dialoges:
   
   set needed     [expr {$totalLabels + $extraTotal + $extraFirstReel}]

   # memorize target amount
   ::Ini::SetData jobdata "PrintData" LayoutNumber  $needed

   # create reel tickets

   set numberOfSubJobs 0
   
   if {$makeReelJobs} {
      # sub-jobs per reel
      if {$excessPerReel} {
         # excess numbers distributed over reels

         set numberOfNumbers  [expr { $totalLabels + $extraTotal}] 

         if {[catch {set numberOfReels    [expr {($totalLabels + $labelsPerReel - 1) / $labelsPerReel}] } errmsg]} {
            ERROR "labelsPerReel invalid: $errmsg"
            ::Jobs::SetJobState $jobid [NumericJobState JobErrorNew]
            return 1
         }

         if {[catch {set extraPerReel     [expr { $extraTotal / $numberOfReels}] } errmsg]} {
            ERROR "numberOfReels must not be 0"
            ::Jobs::SetJobState $jobid [NumericJobState JobErrorNew]
            return 1
         }

         set numbersPerReel   [expr { $labelsPerReel + $extraPerReel}] 

         set sub   1
         set remainingLabels   $totalLabels

         while {$remainingLabels > 0} {
            if {$remainingLabels >= $labelsPerReel} {
               # build for one full reel

               set reelamount [expr {$labelsPerReel + $extraPerReel}]

               if {$sub == 1} {
                  # add extra margin for first reel
                  set reelamount [expr {$reelamount + $extraFirstReel}]
               }
                              
               ::Serials::WriteReelTicket   $jobid $sub $reelamount false
            } else {
               # build last reel
               
               set reelamount [expr {$remainingLabels + $extraPerReel}]

               if {$sub == 1} {
                  # add extra margin for first reel
                  set reelamount [expr {$reelamount + $extraFirstReel}]
               }

               ::Serials::WriteReelTicket   $jobid $sub $reelamount false
            }
            
            set remainingLabels [expr {$remainingLabels - $labelsPerReel}]
            incr sub
         }
      } else {
         # excess numbers on excess reels

         set numberOfNumbers  [expr { $totalLabels + $extraTotal}] 

         if {[catch {set numberOfReels    [expr {($totalLabels + $extraTotal + $labelsPerReel -1) / $labelsPerReel}] } errmsg]} {
            ERROR "labelsPerReel invalid: $errmsg"
            ::Jobs::SetJobState $jobid [NumericJobState JobErrorNew]
            return 1
         }

         set extraPerReel     0
         set numbersPerReel   $labelsPerReel 

         set sub   1
         set remainingLabels   $numberOfNumbers
         
         while {$remainingLabels > 0} {
            if {$remainingLabels >= $labelsPerReel} {
               # build for one full reel

               set reelamount $labelsPerReel

               if {$sub == 1} {
                  # add extra margin for first reel
                  set reelamount [expr {$reelamount + $extraFirstReel}]
               }
               
               ::Serials::WriteReelTicket   $jobid $sub $reelamount false
            } else {
               # build last reel
               
               set reelamount $remainingLabels

               if {$sub == 1} {
                  # add extra margin for first reel
                  set reelamount [expr {$reelamount + $extraFirstReel}]
               }

               ::Serials::WriteReelTicket   $jobid $sub $reelamount false
            }
            
            set remainingLabels [expr {$remainingLabels - $labelsPerReel}]
            incr sub
         }
      }
      
      # memorize number of sub jobs with own sub-job-ticket
      set numberOfSubJobs $numberOfReels
      
   } else {
      # one single job
      ::Serials::WriteReelTicket   $jobid 0 [expr { $totalLabels + $extraTotal}] false
   }

   # report number of sub job tickets for the printer
      
   ::Ini::SetData jobdata "DLS.Results" NumberOfSubJobs  $numberOfSubJobs
   ::Ini::WriteFile $jobini  "utf-8" jobdata

   return 0
}



#----------------------------------------------------------------------
##
# Build one or more serial number files according to configuration
#
# @param jobid  Job ID
# @param kind   Kind of serial number source
# @param interactive 0=background, 1=operator attended processing
#
# @return Status: 0 = ok
#          1 = Input data faulty
#          2 = Not enough numbers
#

         
proc ::Serials::GenerateSerialFiles {jobid kind interactive} {
   variable my
   global  env

   set jobini [file join $::options(JobFolder) $jobid $jobid.\ini]
   
   ::Ini::ReadFile $jobini "utf-8" jobdata ".*" -notrim

#   DEBUG "::Serials::GenerateSerialFiles: jobid=$jobid --- kind=$kind --- interactive=$interactive"

   # check whether jobticket was read
   if {[string equal [::Ini::GetValue jobdata JobSource  JobID ""] ""]} {
      set ticketfile $jobini  ;# for dialog
      SystemErrorDialog   [subst $::txt(err_CannotReadTicket)]
      return 1
   }

   set validKinds [split [string trim [::Ini::GetValue ::iniconfig "Serials.WebService" ValidKinds ""]] "\,"]
   
   if {$kind in $validKinds} \
   {
      set isSAP 1
   } \
   else \
   {
      set isSAP 0
   }
   
   set eancode        [::Ini::GetValue jobdata JobData  EANCode  ""]            ;# optionally padded 

   set excessPerReel  [string equal -nocase [::Ini::GetValue jobdata DLS.Serials  ExcessLabelsPerReel  "no"] "yes"]
   set trackAndTrace  [string equal -nocase [::Ini::GetValue jobdata DLS.Serials  TrackAndTrace        "no"] "yes"]
   set makeReelJobs   [string equal -nocase [::Ini::GetValue ::iniconfig DLS.Jobs SubJobsPerReel       "no"] "yes"]
   set totalLabels    [::Ini::GetValue jobdata DLS.Serials TotalCount.Input      0]
   set extraTotal     [::Ini::GetValue jobdata DLS.Serials ExtraMargin           0]
   set extraFirstReel [::Ini::GetValue jobdata DLS.Serials ExtraMargin.FirstReel 0]
   set labelsPerReel  [::Ini::GetValue jobdata JobData LabelsPerReel             5000]
   
   set haveVarFile    [string equal -nocase [::Ini::GetValue jobdata DLS.Serials HaveVarFile  "no"] "yes"]

   # variables for dialoges:
   
   set needed     [expr {$totalLabels + $extraTotal + $extraFirstReel}]

   # memorize target amount
   ::Ini::SetData jobdata "PrintData" LayoutNumber  $needed

   # build template and header line for mask file
   
   set maskHeadline ""
   set maskLineTemplate ""
   set tab ""
   
   # get all VariableData items
   set vardatalist [::Ini::GetData jobdata VariableData]
   
   if {[llength $vardatalist] > 0} {
      append maskHeadline     $tab "DLSserial" 
      append maskLineTemplate $tab "\\\$Serial\\\\\\"
      set tab "\t" 

      foreach {sym value}  $vardatalist {
         if {[regexp {^(.+)\.ID$} $sym match vardata]} {
            append maskHeadline     $tab [::Ini::GetValue jobdata VariableData "$vardata\.ID"      ""] 
            
            set content [::Ini::GetValue jobdata VariableData "$vardata\.Content" ""]
            
            # check ~pppp~ place holders
            
            if {[regexp {(~([p]+)~).*} $content match ppp pp]} {
               # found pps
               
               if {$isSAP} {
                  # string length is given by DB
                  set len 0
                  set rep "\\\$Serial\\\\\\"
               } else {
                  # string length is defined by the number of 'p' characters
                  set len [string length $pp]
                  
                  set rep "\\\[::Serials::PadSerial \\\$Serial $len\\\]"
               }
               
               regsub $ppp $content $rep content
   #            AckDialog "pp=$pp --- len=$len --- content=$content"
           } 
            append maskLineTemplate $tab $content
         }
      }
   }
   
   # make a command to be executed by the data base
   
   if { ! [string equal $maskLineTemplate ""]} {
      set maskLineTemplate "puts \$fd \"$maskLineTemplate\""

      regsub {\\\\"$} $maskLineTemplate "\"" maskLineTemplate   ;# " strip trailing \ if any
     DEBUG "maskLineTemplate=(($maskLineTemplate))"
   }
   
   # check whether we have enough numbers

   set available [::Serials::AvailableNumbers $jobid]

   if {$needed > $available} {
      ErrorAckDialog [subst $::txt(dlg_NotEnoughSerials)]
      return 2
   }

   # data base has enough numbers: create mask files
   
   if {$interactive} {
      set mono [UserMonolog_Create [subst $::txt(dlg_BuildingMaskFiles)] $::txt(dlg_PleaseWait) $::txt(dlg_PleaseWait)]
   }

   set numberOfSubJobs 0
   
   if {$makeReelJobs} {
      # sub-jobs per reel
      if {$excessPerReel} {
         # excess numbers distributed over reels

         set numberOfNumbers  [expr { $totalLabels + $extraTotal}] 

         if {[catch {set numberOfReels    [expr {($totalLabels + $labelsPerReel - 1) / $labelsPerReel}] } errmsg]} {
            ERROR "labelsPerReel invalid: $errmsg"
            ::Jobs::SetJobState $jobid [NumericJobState JobErrorNew]
            return 1
         }

         if {[catch {set extraPerReel     [expr { $extraTotal / $numberOfReels}] } errmsg]} {
            ERROR "numberOfReels must not be 0"
            ::Jobs::SetJobState $jobid [NumericJobState JobErrorNew]
            return 1
         }

         set numbersPerReel   [expr { $labelsPerReel + $extraPerReel}] 

         set sub   1
         set remainingNumbers  $numberOfNumbers
         set remainingLabels   $totalLabels

         while {$remainingLabels > 0} {
            if {$interactive} {
               UserMonolog_Show $mono [subst $::txt(dlg_BuildingOneMaskFile)]
            }

            if {$remainingLabels >= $labelsPerReel} {
               # build for one full reel

               set reelamount [expr {$labelsPerReel + $extraPerReel}]

               if {$sub == 1} {
                  # add extra margin for first reel
                  set reelamount [expr {$reelamount + $extraFirstReel}]
               }
                              
               ::Serials::WriteSerialsFile  $jobid $sub $labelsPerReel $reelamount $maskHeadline $maskLineTemplate $haveVarFile
#               ::Serials::WriteReelTicket   $jobid $sub $labelsPerReel $reelamount $maskHeadline $maskLineTemplate $haveVarFile
               ::Serials::WriteReelTicket   $jobid $sub $reelamount $haveVarFile
            } else {
               # build last reel
               
               set reelamount [expr {$remainingLabels + $extraPerReel}]

               if {$sub == 1} {
                  # add extra margin for first reel
                  set reelamount [expr {$reelamount + $extraFirstReel}]
               }

               ::Serials::WriteSerialsFile  $jobid $sub $remainingLabels $reelamount $maskHeadline $maskLineTemplate $haveVarFile
#               ::Serials::WriteReelTicket   $jobid $sub $labelsPerReel $reelamount $maskHeadline $maskLineTemplate $haveVarFile
               ::Serials::WriteReelTicket   $jobid $sub $reelamount $haveVarFile
            }
            
            set remainingLabels [expr {$remainingLabels - $labelsPerReel}]
            incr sub
         }
      } else {
         # excess numbers on excess reels

         set numberOfNumbers  [expr { $totalLabels + $extraTotal}] 

         if {[catch {set numberOfReels    [expr {($totalLabels + $extraTotal + $labelsPerReel -1) / $labelsPerReel}] } errmsg]} {
            ERROR "labelsPerReel invalid: $errmsg"
            ::Jobs::SetJobState $jobid [NumericJobState JobErrorNew]
            return 1
         }

         set extraPerReel     0
         set numbersPerReel   $labelsPerReel 

         set sub   1
         set remainingNumbers  $numberOfNumbers
         set remainingLabels   $numberOfNumbers
         
         while {$remainingLabels > 0} {
            if {$remainingLabels >= $labelsPerReel} {
               # build for one full reel

               set reelamount $labelsPerReel

               if {$sub == 1} {
                  # add extra margin for first reel
                  set reelamount [expr {$reelamount + $extraFirstReel}]
               }

               
               ::Serials::WriteSerialsFile  $jobid $sub $labelsPerReel $reelamount $maskHeadline $maskLineTemplate $haveVarFile
#               ::Serials::WriteReelTicket   $jobid $sub $labelsPerReel $reelamount $maskHeadline $maskLineTemplate $haveVarFile
               ::Serials::WriteReelTicket   $jobid $sub $reelamount $haveVarFile
            } else {
               # build last reel
               
               set reelamount $remainingLabels

               if {$sub == 1} {
                  # add extra margin for first reel
                  set reelamount [expr {$reelamount + $extraFirstReel}]
               }

               ::Serials::WriteSerialsFile  $jobid $sub $remainingLabels $reelamount $maskHeadline $maskLineTemplate $haveVarFile
#               ::Serials::WriteReelTicket   $jobid $sub $remainingLabels $reelamount $maskHeadline $maskLineTemplate $haveVarFile
               ::Serials::WriteReelTicket   $jobid $sub $reelamount $haveVarFile
            }
            
            set remainingLabels [expr {$remainingLabels - $labelsPerReel}]
            incr sub
         }
      }
      
      # copy first mask file to a mask file with the name of the job to satisfy the rendering tools

      set firstsub [file join $::options(JobFolder) $jobid $jobid\_1.txt]
      set jobmask  [file join $::options(JobFolder) $jobid $jobid\.txt]
      
      if {[file exists $jobmask]} {
         file delete $jobmask
      }
      
      # maybe we dont have a mask file at all
      
      if {[file exists $firstsub]} {
         file copy $firstsub $jobmask
      }
      

      # memorize number of sub jobs with own sub-job-ticket
      set numberOfSubJobs $numberOfReels
      
   } else {
      # one single job
      ::Serials::WriteSerialsFile  $jobid 0 $totalLabels [expr { $totalLabels + $extraTotal}] $maskHeadline $maskLineTemplate $haveVarFile
#      ::Serials::WriteReelTicket   $jobid 0 $totalLabels [expr { $totalLabels + $extraTotal}] $maskHeadline $maskLineTemplate $haveVarFile
      ::Serials::WriteReelTicket   $jobid 0 [expr { $totalLabels + $extraTotal}] $haveVarFile
   }

   if {$interactive} {
      UserMonolog_Close $mono
      AckDialog [subst $::txt(dlg_WaitForEndOfRendering)]
   }

   # report number of sub job tickets for the printer
      
   ::Ini::SetData jobdata "DLS.Results" NumberOfSubJobs  $numberOfSubJobs
   ::Ini::WriteFile $jobini  "utf-8" jobdata

   return 0
}


#***********************************************************************
##
# Build a serial number file for one reel
#
# @param jobid
# @param sub               Flag: 1=With Sub-Tickets
# @param labelsPerReel     Number of labels to be printed on this reel
# @param numbersPerReel    Number of numbers per reel (reel size)
# @param maskHeadline      
# @param maskLineTemplate  Database command to be performed per line
# @param haveVarFile
#
# Writing to the output file is performed by the database itself!\n
# The command is passed to the DB-engine via "maskLineTemplate"

proc ::Serials::WriteSerialsFile {jobid  sub \
                                  labelsPerReel numbersPerReel\
                                  maskHeadline maskLineTemplate \
                                  haveVarFile} \
{      
   global env
   variable my

   if { ! $haveVarFile} {
      return 0 ;# nothing to do
   }

   if {[catch {::Serials::WriteMaskFile $jobid $sub $numbersPerReel $maskHeadline $maskLineTemplate} errmsg ]} {
      ERROR $errmsg
      ErrorAckDialog $errmsg
      return 1
   }

   return 0
}


#----------------------------------------------------------------------
#** proc   ::Serials::WriteReelTicket {jobid sub \
#**                                 labelsPerReel numbersPerReel}
#**
#** Build a serial number file for one reel
#**
#** in    : lot  = lot id
#**
#** out   : --
#**
#** global: --
#**
#** return: --
#**         
#----------------------------------------------------------------------

proc ::Serials::WriteReelTicket_obsolete {jobid sub \
                                       labelsPerReel numbersPerReel\
                                       maskHeadline maskLineTemplate \
                                       trackAndTrace  haveVarFile} \
{      }


proc ::Serials::WriteReelTicket {jobid sub numbersPerReel haveVarFile} \
{      
   global env
   variable my

   # generate sub-tickets
   
   if {$sub != 0} {
      set reelticketfilename [file join $::options(JobFolder) $jobid $jobid\_$sub\.ini]
   
      if {[catch {open $reelticketfilename "w"} fd]} {
         ErrorAckDialog $errmsg
         return 1
      } else {
         fconfigure $fd -encoding utf-8
         
         puts $fd "\[PrintData\]"
         puts $fd "LayoutNumber=$numbersPerReel"
         puts $fd "\n"
         puts $fd "\[PreRendering\]"
         puts $fd "OutputFile=$jobid\.ctl"
         puts $fd "\n"
         puts $fd "\[RenderingOptions\]"

         if {$haveVarFile} \
         {            
            puts $fd "MaskFile=$jobid\_$sub\.txt"
         }               

         puts $fd "\n"
         
         close $fd
      }
   }

   return 0
}


#----------------------------------------------------------------------
##
#  Write generated serial numbers to mask file
#
# @param jobid            Job ID
# @param sub              Current number of sub-job
# @param needed           Number of serial numbers needed
# @param maskHeadline
# @param maskLineTemplate
#
# @return 0 if successfull, != 0 otherwise
#

proc ::Serials::WriteMaskFile {jobid sub needed \
                               maskHeadline maskLineTemplate} \
{
   global env
   variable my
   
   # open mask file
   
   set maskfilename [file join $::options(JobFolder) $jobid $jobid\_$sub\.txt]

   if {[catch {open $maskfilename "w"} fd]} {
      ErrorAckDialog $errmsg
      return 1
   }

   set dbflag [expr {$sub + 1000}]  ;# 1000=one single file per job
   
   # write serial number ("mask") file
   # first line with IDs
   puts $fd $maskHeadline

   set sql     ""
   append sql "BEGIN TRANSACTION;\n"
   append sql "UPDATE serials SET State = '$dbflag'  WHERE id IN (SELECT id FROM serials WHERE State = '1' LIMIT $needed);\n"
   append sql "SELECT Serial FROM serials WHERE State = '$dbflag' ORDER BY id;\n"
   append sql "END TRANSACTION;\n"
   
   if {[catch {::Serials::SaveExecSQL $jobid $sql [subst $maskLineTemplate]} errmsg]} {
      close $fd
      ERROR "DB error: $errmsg"
      ErrorAckDialog $errmsg
      return 1
   }

   close $fd
}



#********************************************************************
##
# Generate a list of sequential serial numbers
#
# @param jobid   Job ID
# @param start   First number
# @param count   Number of serial numbers to be created
# @param format  Formatting instruction
#
# @return File name of serial number file. Empty if error

proc ::Serials::GenerateSequential {jobid start count format} {
   variable my
   global  env

   set importFileName [file join $::options(JobFolder) $jobid serials.list]
   
   if {[catch {open $importFileName "w"} outfd]} \
   {
      error $outfd
      # error
   }                              

   fconfigure $outfd -encoding utf-8 -translation lf
   
   for {set num $start; set i 0} {$i < $count} {incr num; incr i} \
   {
      set sn [format $format $num]
      puts $outfd $sn
#     DEBUG "sn=$sn"
   } 
   
   close $outfd

   return $importFileName
}



#**********************************************************************
##
# Create a serial number database
#
# @param jobid Job ID
#
# @return 0
#

proc ::Serials::CreateDB {jobid} {
   variable my
   global  env
   
   set dbfile [::Serials::SerialsDBFilename $jobid]

DEBUG "::Serials::CreateDB: jobid=$jobid "   

   if {[catch {sqlite3 serialdb1 $dbfile} errmsg]} {
      ERROR $errmsg
      return -code error $errmsg   ;# error: cannot create data base
   }
   
   catch {serialdb1 close}

   # open data base and build tables if needed
      
   if {[catch {sqlite3 serialdb1 $dbfile} errmsg]} {
      ERROR $errmsg
      return -code error $errmsg  ;# error cannot open data base
   }

   append sql "CREATE TABLE IF NOT EXISTS components (cid VARCHAR NOT NULL UNIQUE, component VARCHAR) ; \n"
   append sql "CREATE TABLE IF NOT EXISTS serials    (id  INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE, Serial VARCHAR UNIQUE, State INTEGER " 
   
   # add component return state columns

   set sql2 ""
   
   foreach {stix component} $::options(ComponentResults) {
      append sql   ",$stix INTEGER"
      append sql2  "INSERT INTO components (cid, component) VALUES ('$stix', '$component'); \n"
   }
   
   append sql ") ; \n"

   append sql $sql2 ;# memorize components 

#   DEBUG "sql=$sql"

   if {[catch {serialdb1 eval $sql } errmsg]} {
      ERROR $errmsg
      return -code error $errmsg
   }

   catch {serialdb1 close}
   
   return 0
}



#**********************************************************************
## 
# Fill an existing serial number database by import file
#
# @param  jobid        Job ID
# @param  importfile   Name of import file
#
# @return
#


proc ::Serials::FillDB {jobid importfile} {
   variable my

   set ts   [clock seconds]
   set now  [clock format $ts -format "%Y-%m-%dT%H:%M:%S" ]
   set now2 [clock format $ts -format "%Y%m%d_%H%M%S" ]
   
   ::Serials::CreateDB $jobid

   set dbfile [::Serials::SerialsDBFilename $jobid]
   set dbfile [file nativename $dbfile]
   
   # open serials data base
   
   if {[catch {sqlite3 serialdb1 $dbfile} errmsg]} {
      ERROR $errmsg
      return -code error $errmsg  ;# error cannot open data base
   }

   set mono [UserMonolog_Create "Import wird vorbereitet" "Bitte warten" "Seriennummern-Import"]

   UserMonolog_Show $mono [subst $::txt(dlg_RegisterImportFile)]

   # read the input file and build other columns 
   
   # build component result columns
   
   set sql2vals ""
   
   foreach {stix component} $::options(ComponentResults) {
      append sql2vals  "\t-1"
   }

   UserMonolog_Show $mono [subst $::txt(dlg_MakeImportCopy)]

   # open importfile
   if {[catch {open $importfile "r"} infd]} {
      UserMonolog_Close $mono
      catch {serialdb1 close}
      return -code error $infd
   }
   
   fconfigure $infd -encoding utf-8 -translation lf

   # open temp file
   set tempfile "[file rootname $importfile]\.temp"   

   if {[catch {open $tempfile "w"} tempfd]} {
      UserMonolog_Close $mono
      catch {serialdb1 close}
      return -code error $tempfd
   }
   
   fconfigure $tempfd -encoding utf-8 -translation lf

   set count 0
   set ix    0
   
   while {![eof $infd]} {
      set serial [gets $infd]
      if {![string equal $serial ""]} \
      {
         incr count
         incr ix
         puts $tempfd "$ix\t$serial\t1$sql2vals"
      }
   }
   
   close $tempfd
   close $infd

   UserMonolog_Show $mono [subst $::txt(dlg_CopyTempToDB)] 

   # now fill with numbers

   set ::count_import 0

   if {[catch {serialdb1 copy "rollback" "serials" $tempfile \t  \\N} errmsg]} {
      catch {serialdb1 close}
      UserMonolog_Close $mono
      catch {file delete $tempfile}
      return -code error $errmsg
   }    

   catch {file delete $tempfile}
   catch {file delete $importfile}

   # counter check: all numbers imported?

   # get newserialindex
   
   set sql "SELECT max(id) FROM serials;"

   if {[catch {set newserialindex [serialdb1 eval $sql] } errmsg]} {
      ERROR $errmsg
      UserMonolog_Close $mono
      catch {serialdb1 close}
      return -code error $errmsg
   }

   UserMonolog_Close $mono

   if {[string equal $newserialindex ""] || [string equal $newserialindex \{\}]} {
      set newserialindex 0
   }

   set realcount $newserialindex
   
   if {($realcount == $count) && ($count != 0)} {
#      set ok [YesNoDialog [subst $::txt(dlg_CorrectImportCount)]]
#      if {$ok} {
#         # user acknowledged correct number
#      } else {
#         # user did not acknowledge correct number : Rollback everything
#
#         if {[catch {file copy -force -- $backupfile $dbfile} errmsg]} {
#            ERROR [subst $::txt(dlg_CannotRestoreSerialsDB)]
#            return -code error [subst $::txt(dlg_CannotRestoreSerialsDB)] 
#         }
#
#         return -code error [subst $::txt(dlg_SerialsDBRestored)] 
#      }
   } else {
      # not the correct number : Rollback everything

      if {[catch {file copy -force -- $backupfile $dbfile} errmsg]} {
         ERROR [subst $::txt(dlg_CannotRestoreSerialsDB)]
         return -code error [subst $::txt(dlg_CannotRestoreSerialsDB)] 
      }

      if {$count == 0} {
         ERROR [subst $::txt(dlg_SerialsImportNull)]
         return -code error [subst $::txt(dlg_SerialsImportNull)] 
      } else {
         ERROR [subst $::txt(dlg_SerialsImportFailed)]
         return -code error [subst $::txt(dlg_SerialsImportFailed)] 
      }
   }

   catch {serialdb1 close}
   return 0
}

#********************************************************************
#** proc  ::Serials::Log {logid {details {}}}
#**
#** Send message to the configured log channels
#**
#** in    : logid   = ID to be used for log and text symbol
#**         details = opt text to be embedded into message 
#**
#** out   : log DB updated
#**
#** global: --
#**
#** return: --
#**
#********************************************************************

proc ::Serials::Log {logid {details {}}} {
   global env
   variable my
 
   # copy for text substitution if any

#   DEBUG "::Serials::Log logid=$logid --- jobid=$jobid"
   
   set UserFullName  $::user(UserFullName)
   set UserID        $::user(UserID)

   set logmsg [subst $::doctxt(log_$logid)]

#   DEBUG "::Serials::Log logmsg=$logmsg"
#   DEBUG "::Serials::Log Channels: [::Ini::GetValue ::iniconfig "Logging" "Log.$logid" ""]"

   foreach chan [split [::Ini::GetValue ::iniconfig "Logging" "Log.$logid" ""] ","] {
#      DEBUG "::Serials::Log chan=$chan"   
      if {![string equal $chan "Dialog"]} {
#      DEBUG "::Serials::Log send to log"

#                       channel class sender    user          msgtext msgid   pv old new reference
         ::Log::Message $chan   MSG   Serials   $UserFullName $logmsg $logid  "" ""  ""  ""
      } else {
         # show dialog
      }
   }
}



#********************************************************************
##
# Evaluate the rules for serial number generation
#
# @param jobid Job ID
#
# @return Key-value list of INI-section to be placed into [DLS.Serials]
#
# This procedure is called by render_jobticket
#

proc ::Serials::EvaluateRules {jobid} {
   global env
   variable my

   set totalCount 0

   set msg ""

   set items [list ExtraMargin.Min 100 ExtraMargin.Max 1000 ExtraMargin 1000 Algorithm "" \
                   Kind None TrackAndTrace "yes" ExtraMargin.FirstReel 0]
   
   foreach {item def} $items {
      set settings($item) $def
   }
   
   # read relevant sections from ini-array
 
   array set settings [::Ini::GetData ::iniconfig {DLS\.Serials$}]

   # check fore more specific rules
   
   set sect 0
   
   foreach section [lsort -dictionary [::Ini::GetSections ::iniconfig {DLS\.Serials\.[0-9]+}]] {
      incr sect
      
      foreach {sym value} [::Ini::GetData ::iniconfig $section] {
         if {[regexp {IF\.([0-9]+)} $sym match order]} {
            # check whether condition matches the job
            
            set conditions($sect,$order) $value 
            set rules($sect,$order)      [::Ini::GetData ::iniconfig $section]
         }
      }
   }

   # apply rules
   
   foreach ix [lsort -dictionary [array names conditions]] {
      if {$::options(ValidationMode)} {
         append msg "$ix\n"
      }

      set sql "SELECT id, JobID, EANCode, TotalCount FROM printjobs WHERE JobID LIKE '$jobid' AND $conditions($ix);"
      if {$::options(ValidationMode)} {
         append msg "sql=$sql\n"
      }
      
      if {[catch {set results [::Jobs::SaveExecSQL $sql]} errmsg]} {
         if {$::options(ValidationMode)} {
            append msg "$errmsg \n"
         }
      } else {
         if {[llength $results] != 0} { 
            set totalCount [lindex $results 3]
            array set settings $rules($ix) 
            if {$::options(ValidationMode)} {
               append msg "rules=$rules($ix) \n"
            }
         }
      }
   }

   # check whether ExtraMargin is defined as a percentage 
   
   set percent ""
   set number  $settings(ExtraMargin)
   
   regexp {^([0-9\.]+)[ ]*([\%])?}  $settings(ExtraMargin) match number percent
   
   if {[string equal $percent "%"]} {
      set settings(ExtraMargin.Input) $settings(ExtraMargin)
      set settings(TotalCount.Input)  $totalCount
      
      set number [expr {round($totalCount * $number / 100)}]

      set settings(ExtraMargin.Computed) $number
      
      if {$number < $settings(ExtraMargin.Min)} {
         set settings(ExtraMargin) $settings(ExtraMargin.Min)
      } elseif  {$number > $settings(ExtraMargin.Max)} {
         set settings(ExtraMargin) $settings(ExtraMargin.Max)
      } else {
         set settings(ExtraMargin) $number
      }
   } \
   else \
   {
      # ExtraMargin is absolute value. Set some parameters for compatibility.
      set settings(ExtraMargin.Input)    $settings(ExtraMargin)
      set settings(ExtraMargin.Computed) $settings(ExtraMargin)
      set settings(TotalCount.Input)     $totalCount
   }
   
   foreach {item} [lsort [array names settings]] {
      # skip IF. parameters
      if { ! [regexp {IF\.*} $item match]} {
         if {$::options(ValidationMode)} {
            append msg "$item = $settings($item)\n"
         }
         
         lappend resultlist $item $settings($item)
      }
   }

   return $resultlist
}


#********************************************************************
#** proc   ::Serials::SaveExecSQL {dbid sql}
#**
#** Execute an SQL query on one of the serial number data bases
#**
#** in    : dbid = database name
#**         sql  = SQL query
#**
#** out   : DB state updated
#**
#** global: --
#**
#** return: results
#**         
#********************************************************************

proc ::Serials::SaveExecSQL {dbid sql {execute {}}} {
   global env
   variable my


   set tries 10
   set ready 0

#   DEBUG  "Serials::SaveExecSQL sql=$sql "  

   while {!$ready} {   
#      DEBUG  "Serials::SaveExecSQL --- 1" 

      set catchresult [catch {set res [::Serials::ExecSQL $dbid $sql $execute]} errmsg]

#      DEBUG  "Serials::SaveExecSQL --- catchresult=$catchresult" 

      if {$catchresult == 0} {
         # TCL_OK
         
         # test response from SQL query
#         DEBUG "Serials::SaveExecSQL: res=$res"

         # success
         return $res
      } elseif {$catchresult == 1} {
         # TCL_ERROR
         # DB error. Not recoverable
         DEBUG  "Serials::SaveExecSQL --- catchresult=$catchresult == TCL_ERROR" 
         ERROR "Serials::SaveExecSQL: $errmsg"
         return -code error $errmsg 
      } elseif {$catchresult == 2} {
         DEBUG  "Serials::SaveExecSQL --- catchresult=$catchresult == TCL_RETURN" 
         # TCL_RETURN
      } elseif {$catchresult == 3} {
         DEBUG  "Serials::SaveExecSQL --- catchresult=$catchresult == TCL_BREAK" 
         # TCL_BREAK
         # DB busy. Recoverable
         incr tries -1
         
         if {$tries <= 0} {
            # all attempts failed
            return -code error ""
         }
      } elseif {$catchresult == 4} {
         DEBUG  "Serials::SaveExecSQL --- catchresult=$catchresult == TCL_CONTINUE" 
         # TCL_CONTINUE
         # DB error. Not recoverable
         return -code error ""
      } else {
         DEBUG  "Serials::SaveExecSQL --- catchresult=$catchresult == UNKNOWN" 
         # unknown code
         return -code error ""
      }

      # we come here if we should try again: wait a while
      
      set tid [clock milliseconds]
      set ::waitdb($tid) 0
      after 1000 "set ::waitdb($tid) 1"
      tkwait variable  ::waitdb($tid)
      unset ::waitdb($tid)
   }
   
   return ""
}


#********************************************************************
#** proc   Serials::ExecSQL {dbid sql}
#**
#** Execute an SQL query on the serial number data base
#**
#** in    : dbid = datbase id
#**         sql  = SQL query
#**
#** out   : DB state updated
#**
#** global: --
#**
#** return: return from query
#**         -code "continue" if databse is busy
#**         -code "break"    if database not usable
#**         -code "error"    if database cannot be opened 
#**         
#********************************************************************

proc ::Serials::ExecSQL {dbid sql execute} {
   variable my
   global env
   
#   DEBUG "Serials::ExecSQL dbid=$dbid --- sql=(($sql)) --- execute=(($execute))"   

   if { ! [info exists ::Serials::DBOpen($dbid)]} {
      set ::Serials::DBOpen($dbid) 0
   } 

   if { ! [info exists ::Serials::DBBusy($dbid)]} {
      set ::Serials::DBBusy($dbid) 0
   } 

   if {$::Serials::DBBusy($dbid)} {
#      DEBUG "Serials::ExecSQL  DB ($dbid) busy"   
      return -code continue  ;# busy
   } else {
#      DEBUG "Serials::ExecSQL DB ($dbid) not busy, execute"   
      set ::Serials::DBBusy($dbid) 1
   }
   

   if {$::Serials::DBOpen($dbid)} {
   } else {
      set dbfilename [::Serials::SerialsDBFilename $dbid]
   
      if {[catch {sqlite3 serialsDB$dbid $dbfilename} errmsg]} {
         ERROR $errmsg
         set ::Serials::DBBusy($dbid) 0
         return -code error  ;# error cannot open data base
      } else {
         serialsDB$dbid timeout 2000  ;# set wait time
         set ::Serials::DBOpen($dbid) 1
      }
   }   

   # SQL log can be inserted here (check for UPDATE, INSERT, DROP ... and write to log)
   
#   DEBUG "JobDB: $sql"

   if {[string equal $execute ""]} {
      if {[catch {set retval [serialsDB$dbid eval $sql] } errmsg]} {
         set errcod [serialsDB$dbid errorcode]
   
   #      DEBUG "Jobs::ExecSQL errcod=$errcod"   
   
         if {($errcod == 5) || ($errcod == 6) } {
#            DEBUG "Serials::ExecSQL --- DB busy, try later"   
            # DB busy, try later
   #         catch {serialsDB$dbid close}
            set ::Serials::DBBusy($dbid) 0
            return -code continue
         } elseif {($errcod == 1)} {
            # SQL error
            DEBUG "Serials::ExecSQL --- SQL error --- $errmsg"   
            set ::Serials::DBBusy($dbid) 0
            return -code error $errmsg
         } else {
            DEBUG "Serials::ExecSQL --- db error"   
            ERROR $errmsg
            catch {serialsDB$dbid close}
            set ::Serials::DBBusy($dbid) 0
            set ::Serials::DBOpen($dbid) 0
            return -code error $errmsg
         } 
      }
   } else {
      if {[catch {set retval [serialsDB$dbid eval $sql $execute] } errmsg]} {
         set errcod [serialsDB$dbid errorcode]
   
   #      DEBUG "Jobs::ExecSQL errcod=$errcod"   
   
         if {($errcod == 5) || ($errcod == 6) } {
            DEBUG "Serials::ExecSQL --- DB busy, try later"   
            # DB busy, try later
   #         catch {serialsDB$dbid close}
            set ::Serials::DBBusy($dbid) 0
            return -code continue
         } elseif {($errcod == 1)} {
            # SQL error
            DEBUG "Serials::ExecSQL --- SQL error --- $errmsg"   
            set ::Serials::DBBusy($dbid) 0
            return -code error $errmsg
         } else {
            DEBUG "Serials::ExecSQL --- db error"   
            ERROR $errmsg
            catch {serialsDB$dbid close}
            set ::Serials::DBBusy($dbid) 0
            set ::Serials::DBOpen($dbid) 0
            return -code error $errmsg
         } 
      }
   }
      
#   DEBUG "Jobs::ExecSQL --- 5"   

   # release DB

   catch {serialsDB$dbid close}
   set ::Serials::DBBusy($dbid) 0
   set ::Serials::DBOpen($dbid) 0

   return $retval
}


# for documentation only:

      #define SQLITE_ERROR        1   /* SQL error or missing database */
      #define SQLITE_INTERNAL     2   /* Internal logic error in SQLite */
      #define SQLITE_PERM         3   /* Access permission denied */
      #define SQLITE_ABORT        4   /* Callback routine requested an abort */
      #define SQLITE_BUSY         5   /* The database file is locked */
      #define SQLITE_LOCKED       6   /* A table in the database is locked */
      #define SQLITE_NOMEM        7   /* A malloc() failed */
      #define SQLITE_READONLY     8   /* Attempt to write a readonly database */
      #define SQLITE_INTERRUPT    9   /* Operation terminated by sqlite3_interrupt()*/
      #define SQLITE_IOERR       10   /* Some kind of disk I/O error occurred */
      #define SQLITE_CORRUPT     11   /* The database disk image is malformed */
      #define SQLITE_NOTFOUND    12   /* Unknown opcode in sqlite3_file_control() */
      #define SQLITE_FULL        13   /* Insertion failed because database is full */
      #define SQLITE_CANTOPEN    14   /* Unable to open the database file */
      #define SQLITE_PROTOCOL    15   /* Database lock protocol error */
      #define SQLITE_EMPTY       16   /* Database is empty */
      #define SQLITE_SCHEMA      17   /* The database schema changed */
      #define SQLITE_TOOBIG      18   /* String or BLOB exceeds size limit */
      #define SQLITE_CONSTRAINT  19   /* Abort due to constraint violation */
      #define SQLITE_MISMATCH    20   /* Data type mismatch */
      #define SQLITE_MISUSE      21   /* Library used incorrectly */
      #define SQLITE_NOLFS       22   /* Uses OS features not supported on host */
      #define SQLITE_AUTH        23   /* Authorization denied */
      #define SQLITE_FORMAT      24   /* Auxiliary database format error */
      #define SQLITE_RANGE       25   /* 2nd parameter to sqlite3_bind out of range */
      #define SQLITE_NOTADB      26   /* File opened that is not a database file */
      #define SQLITE_ROW         100  /* sqlite3_step() has another row ready */
      #define SQLITE_DONE        101  /* sqlite3_step() has finished executing */



