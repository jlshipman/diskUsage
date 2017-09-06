#!/bin/sh
################email################
HOST=`hostname`
WHOM="jeffery.l.shipman@nasa.gov"
Subject=$HOST" Disk Usage"
Subject2=$HOST" Disk Usage  - WARNINGS"

################directories################
baseConfig="/scripts/DiskUsage/"
baseLog=$baseConfig'Log/'
baseTemp=$baseConfig'Temp/'

################files################
#log of script execution
logFile=$baseLog"`date +'%y-%m-%d-%T'| tr : _`.txt"
#one instance to run
check=$baseTemp'checkCheckSum'
logListKeep=$baseTemp"logListKeep.txt"
logListDelete=$baseTemp"logListDelete.txt"
logList=$baseTemp"logList.txt"
diskUsage=$baseTemp"diskUsage.txt"

################variables################
logNum=5
##############create/check directories################
if [ ! -e $baseLog ]; then
   for dir in "$baseTemp $baseLog"; do
      if [ -e $dir ]; then
         echo "     $dir exist"
      else
         echo "     $dir does not exits, will be created"
         mkdir $dir
      fi
   done
fi 
################logging subroutines - begin ################
LOG () 
  { 
     echo " $*" | tee -a $logFile;  
  }

WARN () 
  { 
     LOG "WARNING: $*" 1>&2 ; 
  }

ABORT () 
  { 
     LOG "ABORT: $*" 1>&2 ; 
     /usr/bin/mail -s "$Subject2" $WHOM < $*
     exit 1; 
  }
  
LOG "  Disk Usage script"

##############Log ################
#keep only proscribe number (logNum) of logs
checkLogNum=`ls -1 $baseLog | grep -v '^\.'| wc -l`
if [ $checkLogNum -gt $logNum ] ; then
   LOG "    There are more than $logNum logs"
   ls -1 $baseLog | grep -v '^\.' > $logList
   numToDelete=$((checkLogNum-logNum)) 
   LOG "    numToDelete:  $numToDelete"
   numTail=$((checkLogNum-numToDelete)) 
   LOG "    numTail:  $numTail"
   head -$numToDelete $logList > $logListDelete
   tail -$logNum $logList > $logListKeep
   cat $logListDelete | while read d;
   do
      fullPathLog="$baseLog$d"
      LOG "fullPathLog:  $fullPathLog"
      rm $baseLog$d
      if [ $? -ne 0 ]; then
        WARN "       could delete $d"
        cat ${baseTemp}stderr >>$logFile
        cat ${baseTemp}stderr 1>&2
      fi
   done
fi
#create log file
touch $logFile

if [ -e $check ]; then
   ABORT "double run script check file exists $check"
fi

#create check file
touch $check


#if script dies on hang up, interrupt, quit, or terminate rm check file
trap "rm $check" 0 1 2 15

######################################body begin######################################


df -h | grep disk > $diskUsage

cat $diskUsage | while read i;
do
   usage=`echo "$i" | awk '{print $5}' | tr -d  %`
   if [ $usage -gt 75 ]; then
      drive=`echo "$i" | awk '{print $6}'`
      WARN "Drive $drive is at $usage% capacity"
   else
      drive=`echo "$i" | awk '{print $6}'`
      LOG "Drive $drive is at $usage% capacity"
   fi
done

######################################body end######################################

#if file is not of size zero => there is something to send out
if [ -s $logFile ]; then

    if cat $logFile | grep -iq 'WARN' || cat $logFile | grep -iq 'ABORT' ; then
       /usr/bin/mail -s "$Subject2" $WHOM < $logFile  
    else
       /usr/bin/mail -s "$Subject" $WHOM < $logFile 
    fi
fi
