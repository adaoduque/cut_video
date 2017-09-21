#!/bin/bash
loading() {
    local chars="/-\|"
    while :; do
      for (( i=0; i<${#chars}; i++ )); do
        sleep 0.5
        echo -en "${chars:$i:1}" "\r"
      done
    done
}

task() {
    echo -e "########### Convert your videos to mp3 with time flag ########### \n"
    echo -e "Choose one option \n"
    echo -e "1: Download video from youtube and convert it to mp3 \n"
    echo -e "2: Convert video downloaded only \n"
    return 1;
}

#Add art album to file mp3
function addArtAlbum() {
    #Get filename mp3
    local fileMusic=$1;
    #Get path to filename art album
    local artAlbum=$2;
    local folder="files/";

    ffmpeg -f mp3 -i "$folder$fileMusic" \
           -i "$artAlbum" \
           -c copy -map 0:0 -map 1:0 -id3v2_version 3 \
           -metadata:s:v title="Album cover" \
           -metadata:s:v comment="Cover (Front)" \
           "$folder_$fileMusic" &>/dev/null;
    mv "$folder_$fileMusic" "$folder$fileMusic"
}

#Add metadata Artist, genere...
function addMetadata() {
    #Get filename mp3
    local fileMusic=$1;
    local title=$2;
    local year=$3;
    local artist=$4;
    local author=$5;
    local album=$6;
    local comment=$7;
    local track=$8;
    local genre=$9;
    local folder="files/";

    #Apply metadata
    ffmpeg -i "$folder$fileMusic" \
           -metadata title="$title" \
           -metadata year="$year" \
           -metadata artist="$artist" \
           -metadata author="$author" \
           -metadata album="$album" \
           -metadata comment="$comment" \
           -metadata track="$track" \
           -metadata genre="$genre" \
           "$folder_$fileMusic" &>/dev/null;
    mv "$folder_$fileMusic" "$folder$fileMusic";
}

function convertToMp3() {
    #Get filename
    local fileName=$1;
    #Get path to video file
    local fileNameVideo=$2;
    local folder="files/";

    #Convert to mp3 Bitrate Encoding (VBR)
    ffmpeg -y -i "$folder$fileNameVideo" -vn \
           -acodec libmp3lame -ac 2 -qscale:a 4 -ar 48000 \
            "$folder$fileName.mp3" &>/dev/null;
}

function getTimeElapsedVideo() {
    #Get path video
    local video=$1
    #Getting max time length video in format HH:MM:SS
    local totalTime=$( ffmpeg -i "$video" 2>&1 | grep Duration | awk '{print $2}' | tr -d ,);
    #return it
    echo $( echo $totalTime | cut -d "." -f 1 );
}

function time2Second(){
    #Define local variable 
    local T=$1;
    echo $((10#${T:0:2} * 3600 + 10#${T:3:2} * 60 + 10#${T:6:2})) 
}


#Check if ffmped is installed
command -v ffmpeg >/dev/null 2>&1 || { echo >&2 "Require ffmpeg, but it's not installed. Aborting."; exit 1; }

#Check if youtube-dl is installed
command -v youtube-dl >/dev/null 2>&1 || { echo >&2 "Require youtube-dl, but it's not installed. Aborting."; exit 1; }

#Check if curl is installed
command -v curl >/dev/null 2>&1 || { echo >&2 "Require curl, but it's not installed. Aborting."; exit 1; }

#Check if file time.ini exists
if [ ! -f "time.ini" ]; then
    #Show message
    echo -e "\n\nError: file time.ini doesn't exist. Aborting"; exit 1;
fi;

#Create dir to save all files converted
error=$( mkdir -p files 2>&1 );

#Checks if command mkdir return any error
if [ $? -ne 0 ]; then    
    #Show error and exit script
    echo $error; exit 1;
fi;

#Flag to exist or continue while
finished=0

#Choose task
task

#Get file vídeo for process
while [ $finished -eq 0 ]
do

    #Read data entry
    read optionTask;

    #Check option
    if [ "$optionTask" -eq "1" ]; then
        #Show message
        echo "Enter URL to download video";

        #Read url to download video
        read URLVIDEO
        
        #Check url and get status HTTP. Expected status 200
        status=$(curl -s --head -w %{http_code} "$URLVIDEO" -o /dev/null);

        #Is valid ?
        if [ "$status" -ne "200" ]; then
            #Show error and exit script
            echo "Url is broken. Aborting"; exit 1;
        fi;

        echo "Download video, please wait";

        #Download video
        youtube-dl --no-check-certificate -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio' --output "%(title)s.%(ext)s" --merge-output-format mp4 "$URLVIDEO";

        #Get filename video
        filename=$(youtube-dl --no-check-certificate -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio' --output "%(title)s.%(ext)s" --get-filename "$URLVIDEO");

        #Set filename
        fileVideo=$filename;

        #Get extension vídeo
        extension="${fileVideo##*.}"        

        #Exit while
        finished=1;

    elif [ "$optionTask" -eq "2" ];  then

        echo "Enter path to file"

        #Read data entry
        read fileVideo;

        #Check if file entry exists
        if [ -f "$fileVideo" ]; then

            #Get extension vídeo
            extension="${fileVideo##*.}"

            #Exists, but file vídeo supported ?
            if [[ ! "$extension" =~ (mp4|avi|mkv) ]]; then
                #Show message
                echo -e "\n\nError: Supported files: mp4, avi, mkv\n. Aborting"; exit 1;
            fi;
        else
            #File doesn't exists, error, aborting
            echo -e "\n\nError: Invalid file. Aborting"; exit 1;
        fi

        #Exit while
        finished=1;

    else
        #Clear screen
        clear;
        echo -e "\n\nError: Invalid option\n";
        #Print message again
        task;
    fi
done

#Prevent error download file.
if [ ! -f "$fileVideo" ]; then
    echo -e "\n\nError: video file doens't exist. Aborting"; exit 1;
fi;

#Loading
loading &

#Get PID ID for loading function
pid=$!

readarray lines < time.ini

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
title="";
cover="";
year="";
artist="";
author="";
album="";
comment="";
genre="";
tagsFile="tags.ini";

#Check if tags.ini exists
if [ -e "$tagsFile" ]; then
    #Get all tags
    readarray tags < "tags.ini";
    cover=$( echo "${tags[0]}" | cut -d "=" -f 2 );
    year=$( echo "${tags[1]}" | cut -d "=" -f 2 );
    artist=$( echo "${tags[2]}" | cut -d "=" -f 2 );
    author=$( echo "${tags[3]}" | cut -d "=" -f 2 );
    album=$( echo "${tags[4]}" | cut -d "=" -f 2 );
    comment=$( echo "${tags[5]}" | cut -d "=" -f 2 );
    genre=$( echo "${tags[6]}" | cut -d "=" -f 2 );
fi;

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
    ffmpeg -y -ss "$startCut" -i "$fileVideo" -c copy -t "$finalCut" "files/$nameTrack.$extension" &>/dev/null;

    #Send status
    echo "Converting to mp3";

    #convert file to mp3
    convertToMp3 "$nameTrack" "$nameTrack.$extension";

    echo "Adicionando Meta Tags";

    #Add metadata tags
    addMetadata "$nameTrack.mp3" "$nameTrack" "$year" "$artist" "$author" "$album" "$comment" "$trackNumber" "$genre";

    echo "Adicionando Art Album";

    #Add art album
    addArtAlbum "$nameTrack.mp3" "$cover";

    #remove file video
    rm -rf "files/$nameTrack.$extension"
    
    #Increment more 3
    lineActive=$((lineActive + 3));

done

echo "Finish!!!"

#Finish process load
kill $pid;