#!/bin/bash

if [ "$#" -lt 2 ];
then
	echo "csv2json.sh <search-pattern> <out-dir>"
	echo "Eg. csv2json.sh /home/user/*.csv /home/json"
	exit 2
fi

SEARCH_PATTERN="$1"
OUT_DIR="$2"
which jq
if [ "$?" -ne 0 ];
then
	echo "Requires jq ... exiting"
	exit 2
fi
echo "Output files will be saved in $OUT_DIR"
for fName in $SEARCH_PATTERN; 
do 
	echo "Processing file $fName"; 
	JSON_FILE_NAME=`basename $fName|sed -e "s~deletions.csv-~~g"`
	mkdir -p "$OUT_DIR"
	echo "Output json file is $JSON_FILE_NAME"
	JSON_FILE_NAME="$OUT_DIR/${JSON_FILE_NAME}.json"
	touch "${JSON_FILE_NAME}"
	
	while read -r line;
	do
		#echo "Processing line: $line"
		IFS=',' read -ra CSV_FIELDS <<< "$line"
		#echo "Fields count: ${#CSV_FIELDS[@]}"	
		
		creation_timestamp="${CSV_FIELDS[0]}"
		creator="${CSV_FIELDS[1]}"
		deletion_timestamp="${CSV_FIELDS[2]}"
		deletor="${CSV_FIELDS[3]}"
		subject="${CSV_FIELDS[4]}"
		predicate="${CSV_FIELDS[5]}"
		object="${CSV_FIELDS[6]}"
		language_code="${CSV_FIELDS[7]}"
		
		ts_millis="$[$deletion_timestamp/1000]"
		deletion_timestamp=`date -d @${ts_millis} +"%Y-%m-%d"`
		
		ts_millis="$[$creation_timestamp/1000]"
		timestamp=`date -d @${ts_millis} +"%Y-%m-%d"`
		
		json=`echo "{}"|jq --compact-output --arg ts $timestamp --arg lc $language_code --arg obj $object --arg pred $predicate --arg subj $subject --arg del $deletor --arg dt $deletion_timestamp --arg crt $creator '. |{ timestamp: $ts, creation_timestamp: $ts, creator: $crt, deletion_timestamp: $dt, deletor: $del, subject: $subj, predicate: $pred, object: $obj, language_code: $lc, user_count: 1}'`
		
		if [ "$json" == "" ] || [ -z "$json" ];
		then
			echo "********* Skipping empty line"
			continue
		fi
		
		echo "$json" >> "$JSON_FILE_NAME"		
	done < "$fName"
	OUT_FILE_NAME=`basename $JSON_FILE_NAME`
	aws s3 cp "$JSON_FILE_NAME" "s3://nmane/dataset/$OUT_FILE_NAME"
done