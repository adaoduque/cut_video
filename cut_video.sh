#!/bin/bash
loading() {
    chars="/-\|"
    while :; do
      for (( i=0; i<${#chars}; i++ )); do
        sleep 0.5
        echo -en "${chars:$i:1}" "\r"
      done
    done
}

showMessage() {
    echo -e "########### Convert your videos to mp3 with time flag ########### \n"
    echo -e "Enter file path to video \n"
    return 1;
}

function convertToMp3() {
    #Get filename
    fileName=$1;
    #Get path to video file
    fileNameVideo=$2;

    #Convert to mp3 Bitrate Encoding (VBR)
    ffmpeg -y -i "$fileNameVideo" -vn \
           -acodec libmp3lame -ac 2 -qscale:a 4 -ar 48000 \
            "files/$fileName.mp3" &>/dev/null;
}

function getTimeElapsedVideo() {
    #Get path video
    video=$1
    #Getting max time length video in format HH:MM:SS
    totalTime=$( ffmpeg -i "$video" 2>&1 | grep Duration | awk '{print $2}' | tr -d ,);
    #return it
    echo $( echo $totalTime | cut -d "." -f 1 );
}

time2Second(){
    #Define local variable 
    local T=$1;
    echo $((10#${T:0:2} * 3600 + 10#${T:3:2} * 60 + 10#${T:6:2})) 
}

#Checks if ffmped is installed
command -v ffmpeg >/dev/null 2>&1 || { echo >&2 "Require ffmpeg, but it's not installed. Aborting."; exit 1; }

#Read file and get line until new break line and alloc it array lines
eadarray lines < time.ini

#Get length array
length=${#lines[@]}

#Get length total lines divided by 3 to process in loop for
qtdMinLines=$((length / 3))

#Set line init 0. Array initialize in index 0
lineActive=0;

#Get max line to process
max=$qtdMinLines;

#Initialize variables
startCut="0";
endCut="0";
nameTrack="";
trackNumber="0";

#Create dir to save all files converted
error=$( mkdir -p files 2>&1 );

#Checks if command mkdir return any error
if [ $? -ne 0 ]; then

    #Kill loading
    kill $pid;
    
    #Show error and exit script
    echo $error; exit 1;
fi;

finished=0

showMessage

#Get file vídeo for process
while [ $finished -eq 0 ]
do

    #Read data entry
    read fileVideo;

    #Check if file entry exists
    if [ -f "$fileVideo" ]; then

        #Get extension vídeo
        extension="${fileVideo##*.}"

        #Exists, but file vídeo supported ?
        if [[ ! "$extension" =~ (mp4|avi|mkv) ]]; then
            #Clear screen
            clear;
            #Show message
            echo -e "\n\nError: Supported files: mp4, avi, mkv\n";
            #Print message again
            showMessage;
        else
            #Finish interation loop, all data checked
            finished=1;
        fi;
    else
        #Clear screen
        clear;
        echo -e "\n\nError: Invalid file\n";
        #Print message again
        showMessage;
    fi
done

#Loading
loading &

#Get PID ID for loading function
pid=$!

#Loop
for i in `seq 1 $max`
do

    #Checks if loop variable is equals, it's final interation loop
    if [[ $i -eq $max ]]; then

        #Get time start track and convert it to seconds
        startCut=$( time2Second $( echo "${lines[$((lineActive + 2))]}" | cut -d "=" -f 2 ) );

        #Get time elapsed from vídeo and convert it to seconds
        endCut=$( time2Second $( getTimeElapsedVideo "$fileVideo" ) );        
    else

        #Get time start track and convert it to seconds
        startCut=$( time2Second $( echo "${lines[$((lineActive + 2))]}" | cut -d "=" -f 2 ) );

        #Get time start next song and convert it to seconds
        endCut=$( time2Second $( echo "${lines[$((lineActive + 5))]}" | cut -d "=" -f 2 ) );
    fi;

    #Calculate diferente between time start song and time next song or 
    finalCut=$(( endCut - startCut ))

    #Get track number
    trackNumber=$( echo "${lines[$((lineActive))]}" | cut -d "=" -f 2 );

    #Get track name
    nameTrack=$( echo "${lines[$((lineActive + 1))]}" | cut -d "=" -f 2 );

    #Send status
    echo "Cutting $nameTrack";

    #Cutting large file vídeo with parameters startcut and endcut
    ffmpeg -y -ss "$startCut" -i "$fileVideo" -c copy -t "$finalCut" "files/$trackNumber - $nameTrack.$extension" &>/dev/null;

    #Send status
    echo "Converting to mp3";

    #convert file to mp3
    convertToMp3 "$trackNumber - $nameTrack" "files/$trackNumber - $nameTrack.$extension"

    #remove file video
    rm -rf "files/$trackNumber - $nameTrack.$extension"
    
    #Increment more 3
    lineActive=$((lineActive + 3));

done

echo "Finish!!!"

#Finish process load
kill $pid;