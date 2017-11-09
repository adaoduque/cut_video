#!/bin/bash
_jq() {
    echo ${row} | base64 --decode | jq -r ${1}
}

checkUrl() {
    local urlVideo=$1;
    #Check url and get status HTTP. Expected status 200
    status=$(curl -s --head -w %{http_code} "$urlVideo" -o /dev/null);

    #Is valid ?
    if [ "$status" -ne "200" ]; then
        #Show error and exit script
        echo "Url is broken. Aborting"; exit 1;
    fi;    
}

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
    echo -e "1: Download video and convert it to mp3 \n"
    echo -e "2: Download audio and convert it to mp3 \n"
    echo -e "3: Download only video \n"
    echo -e "4: Download part of video or audio without full download video/audio \n"
    echo -e "5: Convert video downloaded only \n"
    return 1;
}

#Add art album to file mp3
function addArtAlbum() {
    #Get filename mp3
    local fileMusic=$1;
    #Get path to filename art album
    local artAlbum=$2;
    local folder="files/";

    ffmpeg -y -f mp3 -i "$folder$fileMusic" \
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
    ffmpeg -y -i "$folder$fileMusic" \
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

#Check if jq is installed
command -v jq >/dev/null 2>&1 || { echo >&2 "Require jq, but it's not installed. Aborting."; exit 1; }

#Check if file conf.json exists
if [ ! -f "conf.json" ]; then
    #Show message
    echo -e "\n\nError: file conf.json doesn't exist. Aborting"; exit 1;
fi;

Data=$( cat conf.json );

#Create dir to save all files converted
error=$( mkdir -p files 2>&1 );

#Checks if command mkdir return any error
if [ $? -ne 0 ]; then    
    #Show error and exit script
    echo $error; exit 1;
fi;

#Flag to exist or continue while
finished=0;

#Flag to identify download part video or audio without download it complete
isPart=0

#Choose task
task;

#Option to ffmpeg not commom depends optionTask selected
optionConvert="";

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
        #Show message
        echo "Enter URL to download audio";

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

        youtube-dl --no-check-certificate -f 'bestaudio[ext=m4a]/bestaudio' --output "%(title)s.%(ext)s" --merge-output-format m4a "$URLVIDEO";
        
        filename=$(youtube-dl --no-check-certificate -f 'bestaudio[ext=m4a]/bestaudio' --output "%(title)s.%(ext)s" --get-filename "$URLVIDEO");        

        #Set filename
        fileVideo=$filename;

        #Get extension vídeo
        extension="${fileVideo##*.}"

        #Exit while
        finished=1;
    elif [ "$optionTask" -eq "3" ];  then
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
    elif [ "$optionTask" -eq "4" ];  then
        isPart=1;
        isFinished=0;
        optSelected=""
        selection="";
        finished=1;
        isWVideo="video";
        while [ $isFinished -eq 0 ]
        do
            echo "#### $selection ######";
            echo -e "\n1: Only Video\n";
            echo "2: Only Audio";
            #Read data entry
            read optionTask;

            if [ "$optionTask" -eq "1" ]; then
                isFinished=1;
                optSelected=1;
            elif [ "$optionTask" -eq "2" ];  then
                isFinished=1;
                optSelected=2;
                isWVideo="audio";
            else
                #Clear screen
                clear;
                selection="Invalid option, try again";
            fi                
        done;
    elif [ "$optionTask" -eq "5" ];  then
        echo "Enter path to file"

        #Read data entry
        read fileVideo;

        #Check if file entry exists
        if [ -f "$fileVideo" ]; then

            #Get extension vídeo
            extension="${fileVideo##*.}"

            #Exists, but file vídeo supported ?
            if [[ ! "$extension" =~ (mp4|avi|mkv|m4a) ]]; then
                #Show message
                echo -e "\n\nError: Supported files: mp4, avi, mkv and m4a\n. Aborting"; exit 1;
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
done;

#Loading
loading &

#Get PID ID for loading function
pid=$!

cover="";
year="";
artist="";
author="";
album="";
comment="";
genre="";
coverExist="1";
for row in $(echo "${Data}" | jq -r '.tags | @base64'); do  
    cover=$(_jq '.cover');
    year=$(_jq '.year');
    artist=$(_jq '.artist');
    author=$(_jq '.author');
    album=$(_jq '.album');
    comment=$(_jq '.comment');
    genre=$(_jq '.genre');
    #Check if file cover exist
    if [ ! -f "$cover" ]; then
        coverExist="0";
    fi;    
done

if [ "$isPart" -eq "1" ]; then

    #Show message
    echo "Enter URL to $isWVideo";

    #Read url to download video
    read URLVIDEO

    #Check url and get status HTTP. Expected status 200
    checkUrl "$URLVIDEO";

    echo "Download data essential for $isWVideo, please wait";        

    urlDownloadDirect=$( youtube-dl -g --no-check-certificate -f 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio' --output "%(title)s.%(ext)s" --get-filename "$URLVIDEO" );

    #Get links
    video=$( echo $urlDownloadDirect | cut -d " " -f 1 );
    audio=$( echo $urlDownloadDirect | cut -d " " -f 2 );
    name="";
    tIni="";
    tEnd="";


    for row in $(echo "${Data}" | jq -r '.tracks[] | @base64'); do  
        name=$(_jq '.name');
        track=$(_jq '.track');
        staCut=$( time2Second $(_jq '.tIni') );
        endCut=$( time2Second $(_jq '.tEnd') );
        finCut=$(( endCut - staCut ))

        echo "Download $name";

        if [ "$optSelected" -eq "1" ]; then
            ffmpeg -y -ss "$staCut" -i "$video" -c copy -t "$finCut" "files/$name1.mp4"  &>/dev/null;
            ffmpeg -y -ss "$staCut" -i "$audio" -vn -c copy -t "$finCut" "files/$name.m4a"  &>/dev/null;
            ffmpeg -y -i "files/$name1.mp4" -i "files/$name.m4a" -c:v copy -c:a copy "files/$name.mp4"  &>/dev/null;
            rm "files/$name1.mp4" "files/$name.m4a";
        else
            ffmpeg -y -ss "$staCut" -i "$audio" -vn -c copy -t "$finCut" "files/$name.m4a"  &>/dev/null;
            
            echo "Converting to mp3";
            convertToMp3 "$name" "$name.m4a";

            echo "Add Meta Tags";
            #Add metadata tags
            addMetadata "$name.mp3" "$name" "$year" "$artist" "$author" "$album" "$comment" "$track" "$genre";
            #Check if cover file exist
            if [ "$coverExist" -eq "1" ]; then
                echo "Add Art Album";
                #Add art album
                addArtAlbum "$name.mp3" "$cover";
            fi;

            rm "files/$name.m4a";
        fi
       
    done    

else
    #Verify if it is m4a
    if [[ "$extension" = "m4a" ]]; then
        #Add parameter -vn because it is m4a file.
        #-vn means that only the audio stream is copied from the file.
        optionConvert=" -vn ";
    fi;

    if [ \( "$optionTask" -eq "1" \) -o \( "$optionTask" -eq  "2" \) -o \( "$optionTask" -eq  "3" \) -o \( "$optionTask" -eq  "5" \) ]; then
        name="";
        tIni="";
        tEnd="";


        for row in $(echo "${Data}" | jq -r '.tracks[] | @base64'); do  
            name=$(_jq '.name');
            track=$(_jq '.track');
            staCut=$( time2Second $(_jq '.tIni') );
            endCut=$( time2Second $(_jq '.tEnd') );
            finCut=$(( endCut - staCut ))

            #Send status
            echo "Cutting $name";

            #Cutting large file vídeo with parameters startcut and endcut
            ffmpeg -y -ss "$staCut" -i "$fileVideo" $optionConvert -c copy -t "$finCut" "files/$name.$extension" &>/dev/null;

            #Send status
            echo "Converting to mp3";

            #convert file to mp3
            convertToMp3 "$name" "$name.$extension";

            echo "Add Meta Tags";
            #Add metadata tags
            addMetadata "$name.mp3" "$name" "$year" "$artist" "$author" "$album" "$comment" "$track" "$genre";
            #Check if cover file exist
            if [ "$coverExist" -eq "1" ]; then
                echo "Add Art Album";
                #Add art album
                addArtAlbum "$name.mp3" "$cover";
            fi;

            rm "files/$name.$extension";

        done;        
    fi;

fi;

echo "Finish!!!";

#Finish process load
kill $pid;