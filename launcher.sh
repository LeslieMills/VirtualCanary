#!/usr/bin/bash

HDRFILE=/home/canary/.aes/snsrs.txt #Sensor Header File
BFRFILE=/home/canary/.aes/bkp.txt   #Data Buffer File
DATLOG=/home/canary/.aes/Datalog.txt #Sensor Data Log File
PROGDIR=/home/canary/.aes/dist/	     #Directory where program executable is located
PRGEXEC=CanaryLogger* #Executable program 

MAXBUFFRECORD=300
sleepTime=600 #sleep for program in seconds: 300 = 5 minutes
NIL=0

BASE_GPIO_PATH=/sys/class/gpio
#Pin designation
SWITCHPIN=26
ENGATEPIN=5
ON="1"
OFF="0"

#---------------------------------------------------------------------------------
exportPin()
{
	if [ ! -e $BASE_GPIO_PATH/gpio$1 ]; then
		echo "$1" > $BASE_GPIO_PATH/export
	fi
}
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
	setPinState $ENGATEPIN $OFF
}
#---------------------------------------------------------------------------------
switchPinsOn()
{
	setPinState $SWITCHPIN $ON
	setPinState $ENGATEPIN $ON
}
#---------------------------------------------------------------------------------
shutdown()
{
	switchPinsOff
	killall -w $PRGEXEC 2>/dev/null
	sleep 90
	exit 0
}
#---------------------------------------------------------------------------------
trap shutdown SIGINT
exportPin $SWITCHPIN
exportPin $ENGATEPIN
setOutput $ENGATEPIN
setOutput $SWITCHPIN
#---------------------------------------------------------------------------------
#---------------------------------------------------------------------------------
###################################################################################
#			INITIALIZATTION SECTION

#killall -w $PRGEXEC #Stop the running of a current version of CanaryLogger programm
#switchPinsOff
#sleep 10 #wait for complete power cut-off to the control board
#----------------------------------------------------------------------------------
			#RESET CONTROL BOARD

echo "Initiating Launcher Program"
#---------------------------------------------------------------------------------
if [ -e $HDRFILE ]; then
	rm $HDRFILE #DELETE THE FILE
	echo "Header File Deleted"
fi

#---------------------------------------------------------------------------------
#		INITIAL DATALOG AND BUFFER CHECK  

if [ -e $BFRFILE ]; then
	wcount=$(wc -l $BFRFILE | sed 's/\|/ /' | awk '{print$1}')
	bufflines=$(( $wcount ))
	if [ $bufflines -gt 200000 ]; then 
		rm $BFRFILE
	fi
fi


if [ -e $DATLOG ]; then
	wcount=$(wc -l $DATLOG | sed 's/\|/ /' | awk '{print$1}')
	dlines0=$(( $wcount ))
else
	dlines0=0
fi
sleep 10
###################################################################################
cd $PROGDIR
killall -w $PRGEXEC 2 >/dev/null #Stop the running of a current version of CanaryLogger programm
echo "M" > /dev/serial0
sleep 30
switchPinsOff
#sleep 30 #wait for complete power cut-off to the control board

switchPinsOn #send power to the control board and indicate for raspberry pi program run
#sleep 30 #wait 50 seconds 

chmod +x $PRGEXEC
./$PRGEXEC & disown

sleep $sleepTime #Sleep beore entering main script loop
###################################################################################
#		CHECK POINT FOR SENSOR HEADER FILE
wcount=$(wc -l $HDRFILE | sed 's/\|/ /' | awk '{print$1}')
lines=$(( $wcount ))
if [ -e $HDRFILE ]; then
	if [ "$lines" -eq "$NIL" ]; then
		#echo "Sensor Header File Empty" >> tracker.txt 
		echo "Header File Error: Rebooting System..."
		killall -w $PRGEXEC 2 > /dev/null
		echo "M" > /dev/serial0
		systemctl reboot
		sleep 90
	fi
else
	echo "Header File Error: Rebooting System...."
	killall -w CanaryLoggerv4 2  >/dev/null
	systemctl reboot
	sleep 90
	
fi
###################################################################################
#			MAIN SCRIPT LOOP			
while true; do
	#DATALOG FILE CHECKPOINT
	wcount=$(wc -l $DATLOG | sed 's/\|/ /' | awk '{print$1}')
	dlines1=$(( $wcount  ))
	if [[ ! -e "$DATLOG" ]] ||  [[ "$dlines0" -eq "$dlines1"  ]] ;then
		echo "Datalog File Error: Rebooting System"	
		echo "M" > /dev/serial0
		killall -w $PRGEXEC 2>/dev/null
		systemctl reboot
		sleep 90
	else
		dlines0=$dlines1
	fi

	#BUFFER FILE CHECKPOINT
	if [ -e "$BFRFILE"  ]; then
		wcount=$(wc -l $BFRFILE | sed 's/\|/ /' | awk '{print$1}')
		bufflines=$(( $wcount ))

		if [ "$bufflines" -ge "$MAXBUFFRECORD" ]; then
			echo "BUFFER File Error: Rebooting System"
			killall -w $PRGEXEC 2>/dev/null
			echo "M" > /dev/serial0
			systemctl reboot
			sleep 90
		fi
		
	fi

	#CHECK IF PROGRAM IS RUNNING
	prgcount=$(ps -afux | grep $PRGEXEC | wc -l)
	if [ $prgcount -lt 3  ]; then
		echo "Program Terminated Unexpectedly...Resetting Control Board"
		echo "M" > /dev/serial0 #send a signal to reset the motherboard
		sleep 20 #sleep for 20 seconds
		setPinState $ENGATEPIN $OFF #switch the power to the control board off and wait for it power dissipation
		sleep 100
		setPinState $ENGATEPIN $ON #switch the power to the control board on and wait for it to come alive		
		sleep 30 #sleep for 30 seconds for the control board to completely initialize
		./$PRGEXEC & disown
	fi

	sleep $sleepTime	
done
###################################################################################

