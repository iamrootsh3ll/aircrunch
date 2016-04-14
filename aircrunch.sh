#!/bin/bash

#Color Codes
Gr="\e[0;32m"  		#Green
Br="\e[0;33m"		#Brown
Yl="\e[1;33m"		#Yellow
Pr="\e[0;35m"		#Purple
Bl="\e[0;34m"		#Blue
Rd="\e[0;31m"		#Red
Wh="\e[0;m"		#White
Bold="\e[1m"		#Bold
Dim="\e[2m"		#Dim
Ul="\e[4m"		#UnderLine

version="${Gr}${Bold}AirCrunch${Wh} version 1.0 (${Gr}C${Wh}) 2016"

#Banner of the script
banner()
{
	echo -ne \
"\
   ${Bold}_________________________________________________${Wh}\n\
  |${Gr}${Bold}AirCrunch${Wh}: ${Dim}Effortless WPA/2 Cracking${Wh} ${Pr}1.0 (C) 2016${Wh}|\n\
  |${Gr}${Bold}Author${Wh}   : ${Gr}(Su)shant Bhatia${Wh}			    |\n\
  |${Gr}${Bold}Website${Wh}  : ${Bl}${Ul}http://www.rootsh3ll.com${Wh}		    |\n\
   ${Dim}${Bold}-------------------------------------------------${Wh}\n\
"
}

#Type "$0 -h" for help menu
help_fn()
{
	echo -ne \
"
  ${Gr}Usage${Wh}   : $0 -c <${Dim}.Cap file${Wh}> -e <${Dim}ESSID${Wh}> -w [${Dim}Wordlist${Wh}] [crunch] <${Dim}Options${Wh}>\n\
  Option  :\n\
    -h	  : Help menu
    -i	  : Install to disk
    -v    : Version\n
  Stdin Options :
	^Z	: Pause/Resume Aircrunch
	^C	: Quit
"
	exit
}

#Checking the dependencies of aircrunch (i.e. aircrack-ng, crunch & tshark)
dependencies_check()
{	
	internet="ping -c 1 www.google.com "
	install_dependencies="sudo apt-get install"
	install_status=0
	if [[ ! $(which aircrunch) ]]; then	
		if [[ ! -f /tmp/.status_file ]]; then
			echo -ne "${Rd}Aircrunch is not installed${Wh}\nDo you want to install aircrunch(/usr/bin) [Y/n]: "
			read -n 1 choice
			if [[ -z $choice || $choice = "Y" || $choice = "y" ]];then
				sudo cp $0 /usr/bin/aircrunch
				sudo chmod +x /usr/bin/aircrunch
				rm /tmp/.status_file 2> /dev/null 
				echo -e "\n${Gr}Aircrunch installed successfully${Wh}"
			elif [[ $choice = "n" || $choice = "N" ]]; then
				touch /tmp/.status_file
			fi
		fi
	fi
	if [[ ! $(which crunch) && $status -eq 1 ]]; then 
		install_dependencies+=" crunch"
		install_status=1
			
	fi
	if [[ ! $(which aircrack-ng) ]]; then
		install_dependencies+=" aircrack-ng"
		install_status=1
	fi
	
	if [[ ! $(which tshark) ]]; then
		install_dependencies+=" tshark"
		install_status=1
	fi

	if [[ $install_status -eq 1 ]];then
		if [[ $($internet 2> /dev/null) ]];then
			$install_dependencies
			tput clear
		else
			echo -e "${Rd}[!] ${Yl}Dependencies are not installed.${Wh}"
			echo -e "${Rd}No internet connection found${Wh}"
			exit
		fi
	fi
}


#For Integrating crunch in the script.	
#Syntax  :- $ aircrunch -c [.cap file] -e [essid] crunch <options>
#Example :- $ aircrunch -c rootsh3ll-01.cap -e rootsh3ll crunch 8 8
longArg()
{	
	status=0		#For checking the presence of crunch, 0=Doesn't Exist
	for var in "$@"
	do
		if [[ $status -eq 1 ]]; then		
			crunch+=" $var"		#crunch here is a variable not a command, call using $crunch
		fi

		if [[ $var = "crunch" ]]; then
			crunch="crunch"		
			status=1	
		fi		
	done

	if [[ $status -eq 1 ]]; then
			crunch+=" |"		
	fi	
}

#To pass crunch's output in aircrack-ng as input
#Example:- $ crunch 8 8 | aircrack-ng -w - rootsh3ll-01.cap -e rootsh3ll 
#APid is PID of aircrack-ng 
#CPid is PID of crunch
##Computing the APid while running the aircrack-ng later in the script.
getPid()
{
	CPid=$[ $APid-1 ]	# If PID of left command(crunch 8 8) is x then PID of right command(aircrack-ng) is x+1 
}

#Prints the Invalid option 
validate()
{
	Invalid_Option=$1
	echo -e "Please Enter a valid $Invalid_Option"
}

#Validates the ESSID entered by user in the given Cap file using tshark.
validate_ssid ()
{

	ssid_command=$(\
			tshark -r $capfile -Y "eapol || \
							wlan_mgt.tag.interpretation eq $ssid || \
							(wlan.fc.type_subtype==0x08 && wlan_mgt.ssid eq $ssid)" |\
							 grep SSID |\
							 awk '{print $14}')
	eval "$ssid_command" 		#Executes the command

}

#A Recursive function to validate the existence of password-file in the current directory
check_existence()
{
	pass=$1
	passfile="$pass$2$3"
	if [[ -f $passfile ]];then
	file_status=1;
	else 
	file_status=0;
	fi
	if [[ $file_status -eq 1 ]];then
	x=$[ $x+1 ]
	check_existence $pass "." "$x"
	else
	file_status=0
	fi
}

#Store the name of the password-file to be used for saving password in a variable name passfile.
savefile()
{
	passfile=$(basename $capfile .cap)
	passfile+=".pw"
	check_existence $passfile
}

#Handles the signal interrupt sent to the shell.
trap terminate 2		# 2 stands for SIGINT(^C), see man SIGNAL for more info

terminate()
{
	tput clear
	getPid
	kill -9 $APid 2> /dev/null
	echo -e "\n${Gr}Is that all you got, huh!? ${Wh}"		#WHY SO SERIOUS??
	exit

}

trap pause 19 23 24 20 17 18	#Integers for SIGSTOP & SIGSTP, see man SIGNAL for more info
pause()
{	 
	getPid
	if [[ -z $crunch ]];then
		tput clear

		kill -SIGSTOP $APid 2> /dev/null

		echo -e "\nNeed some rest? ${Yl}Paused${Wh}             "
		echo -e "${Gr}Press any key to continue...${Wh}"

		trap terminate 2		
		read -n 1

		kill -SIGCONT $APid 

		tput clear

		sleep 0.5
		echo -e "\nAircrack Status: ${Gr}Running${Dim}...${Wh}"
		echo -e "Press ${Rd}[^C]${Wh} to exit or ${Gr}[^Z]${Wh} to pause"

		wait
	else
		tput clear
		echo -e
		
		kill -SIGSTOP $CPid $APid 2> /dev/null

		echo -e "\nAircrack Status: ${Yl}Paused${Wh}"
		echo -e "${Gr}Press any key to continue...${Wh}"

		trap terminate 2		
		read -n 1

		kill -SIGCONT $CPid $APid 

		tput clear

		sleep 0.5
		echo -e "\nAircrack Status: ${Gr}Running${Wh}..."
		echo -e "Press ${Rd}[^C]${Wh} to exit or ${Yl}[^Z]${Wh} to pause"

		wait
	fi
}

#Handles the flags and its arguments.
while getopts c:e:hivw: opt
do
    case "$opt" in	
	c)  capfile=$OPTARG ;;	
	e)  ssid=$OPTARG ;;
	h)  help_fn ;;
	i)  sudo cp $0 /usr/bin/aircrunch
	    sudo chmod +x /usr/bin/aircrunch
	    echo -e "\n${Gr}Aircrunch installed successfully${Wh}"
	    echo -e "\nCheck Install location: $ which aircrunch"
	    exit 0 ;;
	v)  echo -e $version
	    exit 0 ;;
	w)  dictionary="$OPTARG" ;;   
	\?) # unknown flag
      	  echo 2>&1
	  help_fn	  
	  exit 0;;
    esac
done

#Check if wordlist is provided or not.
if [[ -z $dictionary ]];then	
	longArg $@
fi

if [[ ! $1 ]] ; then
	banner
	help_fn
fi

dependencies_check

#Validates the existence of capfile and ESSID in the script arguments.
if [[ -n $capfile && -n $ssid ]]; then
	
	#Validates if the entered wordlist is a valid text file or not.
	if [[ -f $dictionary ]] && [[ $( file "$dictionary" | grep "ASCII text" ) ]];then
		status_dict=1; 		
	else
		if [[ "$dictionary" = "" ]] ;then
			dictionary='-'; status_dict=1;
		else
		validate "Wordlist"
		status_dict=0
		fi
	fi
	
	#Validates if the entered capfile is a valide tcpdump capture file or not.
	if [[ -f $capfile ]] && [[ $( file "$capfile"|grep "tcpdump capture file" ) ]]; then
		status_cap=1
	else 	
		validate "Cap File"		
		status_cap=0		
	fi

	#Validate if the entered ESSID is present in the cap file or not.
	validate_ssid
	if [[ "${ssid}" = "${SSID}" ]]; then
		status_ssid=1		
	else
		validate "ESSID"
		status_ssid=0
	fi
fi 

#If it passes all the validation then it will run the aircrack-ng
if [[ $status_dict -eq 1 && $status_cap -eq 1 && $status_ssid -eq 1 ]]; then
	savefile
	command="$crunch aircrack-ng -w $dictionary $capfile -e $ssid -l $passfile & sleep 0.5"
	eval $command; APid=$!
	if [[ -n $crunch ]];then
		sleep 2.7
	fi

	echo -e
	echo -e "Aircrack Status: ${Gr}Running...${Wh}"
	echo -e "Press ${Rd}[^C]${Wh} to exit or ${Yl}[^Z]${Wh} to pause"
	wait 
	tput clear

	if [ -f $passfile ];then
		echo -e "Password found for $ssid is :- ${Gr}`cat $passfile`${Wh}\n"
		echo -e "Password is saved in a file :- ${Gr}${Dim}$(pwd)${Wh}/${Br}${Ul}$passfile${Wh}"
		echo -e "\nKeep Cracking.. See you Again ;) ${Wh}"
	else
		echo -e "${Rd}Passphrase not found${Wh} :(....Please try another wordlist."
		echo -e "\n${Gr}Exiting the Script...${Wh}"		
	fi
else 
	help_fn	
fi
