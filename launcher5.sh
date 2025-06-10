#!/bin/bash

SNSRFILE=/home/canary/.aes/snsrs.txt #Sensor Header File
HDRFILE=/home/canary/.aes/dist/hdr.txt #spec sensor header file
BFRFILE=/home/canary/.aes/bkp.txt   #Data Buffer File
DATLOG=/home/canary/.aes/Datalog.txt #Sensor Data Log File
PROGDIR=/home/canary/.aes/dist/	     #Directory where program executable is located
PRGEXEC=CanaryLogger* #Executable program 

MAXBUFFRECORD=20000
sleepTime=1200 #sleep for program in seconds: 300 = 5 minutes
NIL=0
#---------------------------------------------------------------------------------
exportPin()
{
	if [ ! -e $BASE_GPIO_PATH/gpio$1 ]; then
		echo "$1" > $BASE_GPIO_PATH/export
	fi
}
#---------------------------------------------------------------------------------
check_connection()
{
	pingcount="$(ping -c 4 8.8.8.8 | grep time= | wc -l)" 2>/dev/null
	if [ "$pingcount" -ge 4 ]; then
		switchPinsOn
		echo "Connected to Network"
	else
		echo "No Network Connection"
		switchPinsOff
	fi
}
#---------------------------------------------------------------------------------

#---------------------------------------------------------------------------------
setOutput()
{
	echo "out" > $BASE_GPIO_PATH/gpio$1/direction
}
#---------------------------------------------------------------------------------
setPinState()
{
	echo $2 > $BASE_GPIO_PATH/gpio$1/value
}
#---------------------------------------------------------------------------------
switchPinsOff()
{
	setPinState $SWITCHPIN $OFF
	setPinState $NETPIN $OFF
}
#---------------------------------------------------------------------------------
switchPinsOn()
{
	setPinState $SWITCHPIN $ON
	setPinState $NETPIN $ON
}
#---------------------------------------------------------------------------------
shutdown()
{
	kill -SIGINT $PID
	sleep 2
	exit 0
}
#---------------------------------------------------------------------------------
hardware_reset()
{
	echo "Initiating Hardware Reset..."
	setPinState $RSTPIN $OFF #active low state to reset the board
	sleep 8 #wait 8 seconds after reset
	setPinState $RSTPIN $ON  #turn pin back to high get out of reset
	sleep 6m  #Sleep for 5 minutes so all sensors initialize
	echo "Reset Complete..."
}
#---------------------------------------------------------------------------------
soft_reset()
{
	echo "M" > /dev/serial0
	sleep 30 #wait 20 seconds before issuing second reset
	echo "M" > /dev/serial0
	sleep 30
}
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------

#---------------------------------------------------------------------------------
###################################################################################
#			INITIALIZATTION SECTION

#killall -w $PRGEXEC #Stop the running of a current version of CanaryLogger programm
#switchPinsOff
#sleep 10 #wait for complete power cut-off to the control board
#----------------------------------------------------------------------------------
			#RESET CONTROL BOARD

echo "Starting Launcher Program"
cd $PROGDIR
killall -w $PRGEXEC 2>/dev/null #Stop the running of a current version of CanaryLogger programm
#---------------------------------------------------------------------------------
if [ -e $HDRFILE ]; then
	rm $HDRFILE #DELETE THE FILE
	echo "Header File Deleted"
fi

#---------------------------------------------------------------------------------
if [ -e $SNSRFILE ]; then
	rm $SNSRFILE #Delete the sensor file
	echo "Sensor File Deleted"
fi
#---------------------------------------------------------------------------------
#		INITIAL DATALOG AND BUFFER CHECK  

if [ -e $BFRFILE ]; then
	wcount=$(wc -l $BFRFILE | sed 's/\|/ /' | awk '{print$1}')
	bufflines=$(( $wcount ))
	if [ $bufflines -gt 20000 ]; then 
		tail -n 20000 $BFRFILE > $BFRFILE
		#rm $BFRFILE
	fi
fi


if [ -e $DATLOG ]; then
	wcount=$(wc -l $DATLOG | sed 's/\|/ /' | awk '{print$1}')
	dlines0=$(( $wcount ))
else
	dlines0=0
fi
###################################################################################
#					FAN COOLING SYSTEM CHECK
COOLEREXEC=fanserver
cff=$(find /home/canary/.aes/dist 2>/dev/null | grep fanserver | wc -l)
#echo "CFF VARIABLE:$cff"
if [ $cff -eq 1 ]; then
	echo "Cooling System Activated"
	chmod6+x $COOLEREXEC 
	./$COOLEREXEC &
else
	echo "Cooling System Deactivated"
fi
	
###################################################################################
chmod +x $PRGEXEC
trap shutdown SIGINT
./$PRGEXEC $1 
PID=$!
sleep 5 #Wait for program to show up
echo "Launcher Program PID: $PID"
sleep $sleepTime #Sleep before entering main script loop
###################################################################################
#			MAIN SCRIPT LOOP			
###################################################################################
#Reset sleepTime variable for loop
sleepTime=5m
while true; do
	#DATALOG FILE CHECKPOINT
	wcount=$(wc -l $DATLOG | sed 's/\|/ /' | awk '{print$1}')
	dlines1=$(( $wcount  ))
	if [[ ! -e "$DATLOG" ]] ||  [[ "$dlines0" -eq "$dlines1"  ]] ;then
		echo "Datalog File Error: Reseting Device..."	
		killall -w $PRGEXEC 2>/dev/null
	else
		dlines0=$dlines1
	fi

	#CHECK IF PROGRAM IS RUNNING
	prgcount=$(ps -afux | grep $PRGEXEC | wc -l)
	if [ $prgcount -lt 3  ]; then
		echo "Program Terminated Unexpectedly...Rebooting System!"
		systemctl reboot
		sleep 90
	fi
	sleep $sleepTime	
done
###################################################################################

