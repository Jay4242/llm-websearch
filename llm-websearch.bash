#!/bin/bash

#Set overall temperature. (Where not explicitly set, ie. 0.0)
temp="0.7"
date=$(date +"%Y-%m-%d")

# Create a unique temporary directory
temp_dir=$(mktemp -d /dev/shm/llm-websearch.XXXXXX)
trap 'rm -rf "$temp_dir"' EXIT

# Determine which html2text to use
HTML2TEXT_BIN="/usr/bin/html2text"
if [[ ! -x "${HTML2TEXT_BIN}" ]]; then
    HTML2TEXT_BIN="html2text" # Fallback to PATH if /usr/bin/html2text doesn't exist or isn't executable
fi

#Take in a question or search term if user didn't supply it as a parameter.
if [ -z "$1" ]; then
   read -p "What are you searching for?: " sterm
else
   sterm=$*
fi

#until [[ "${echeck}" == "TRUE" ]] ; do
#Generate a search phrase and SearX URL using the LLM.
#url=$(llm-python-chat.py "You are a Searx Search Engine Assistant.  Searx uses search URLs such as \`http://searx.lan/search?q={}&language=auto&time_range=&safesearch=0&categories=general\` where \`{}\` is the search term.  Pick the best possible search phrase to help the user find what they're looking for. Output only the Searx search URL and nothing else." "${sterm}" "${temp}" | sed -e 's/\\n//g' -e 's/```//g' -e 's/ //g' | tr -d '\n')
phrase=$(llm-python-chat.py "You are a Search Engine Assistant. Today's date is ${date}. You output the best possible search phrase to help the user find information about their question or research topic. Output ONLY the search phrase they should use and no explanation." "${sterm}" "${temp}" --rm-think | sed -e 's/\\n//g' -e 's/```//g' -e 's/ /+/g' -e 's/"//g' | tr -d '\n')
url="http://searx.lan/search?q=${phrase}&language=auto&time_range=&safesearch=0&categories=general"
#check if the URL is valid using the LLM.
#echeck=$(llm-python-chat.py "You are a Searx Search Engine Assistant.  Searx uses search URLs such as \`http://searx.lan/search?q={}&language=auto&time_range=&safesearch=0&categories=general\` where \`{}\` is the search term.  Check if the URL is a valid Searx link.  Only output \`TRUE\` if the link is valid or \`FALSE\` if it's not valid." "${url}" "0.0" | sed -e 's/ .*//g')

#If the error check fails, alert the user and exit.
#if [[ "${echeck}" == "FALSE" ]] ; then
#   echo "${url} failed error checking."
#fi
#done
#Display the generated URL to the user.
echo "${url}"

#Get the websites supplied by SearX.
while [ -z "${links}" ] ; do
   mapfile -t links < <(curl -s "${url}" | htmlq '#urls' | tr -d '\n' | sed -e 's/<article class=/\n/g' | grep "^\"result" )
done

#For each website go through the loop.
for link in "${links[@]}" ; do

   #Save the Link URL
   lurl=$(echo "${link}" | sed -e 's/.*url_header" href="//g' -e 's/".*//g')

   #Save the Link Description
   ldesc=$(echo "${link}" | sed -e 's/.*class="content">//g' -e 's/<div class="engines".*//g' | htmlq --text | grep -v '^[[:space:]]*$')

   #Ask the LLM if the Description implies the website will help us.  Yes/No.
   ans=$(llm-python-chat.py "You are a helpful research assistant." "We're trying to research \`${sterm}\`. The search engine gave back \`${lurl}\` as a possibility to find out more.  The following is a brief excerpt from the search engine: \`\`\`${ldesc}\`\`\`.  Should we read this page for more information? Always start your answer with \`Yes\` or \`No\`." "${temp}" --rm-think | sed -e 's/\\n/ /g' -e "s/*//g" -e 's/\\//g' | tr -d '\n')

   #Test if the bot thought the website would be helpful.
   if [[ "${ans}" == Yes* ]] ; then
      if [[ "${lurl}" =~ youtube.com/watch ]] || [[ "${lurl}" =~ youtu.be/ ]] ; then
         # It's a YouTube video, use yt-dlp to get subtitles
         if yt-dlp --no-playlist --no-warnings -q --skip-download --sub-format srv3 --write-auto-subs "${lurl}" -o "${temp_dir}/video" 2>/dev/null ; then
            if cat "${temp_dir}/video.en.srv3" | "${HTML2TEXT_BIN}" > "${temp_dir}/llm-websearch.txt" ; then
               echo "Used YouTube Automatic Subtitles."
            else
               echo "Failed to process YouTube subtitles from srv3 file."
               continue # Skip this link if subtitle processing fails
            fi
         else
            echo "No YouTube subtitles found for ${lurl} or yt-dlp failed."
            continue # Skip this link if yt-dlp fails
         fi
      else
         # Not a YouTube video, proceed with existing logic for PDF/webpage
         type=$(curl -s -L -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36' -I "${lurl}")
         if [[ "${type}" == "[Pp][Dd][Ff]" ]] ; then
            #Convert the pdf2txt
            wget -U 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36' -c "${lurl}" -O "${temp_dir}/llm-websearch.pdf"
            pdf2txt "${temp_dir}/llm-websearch.pdf" > "${temp_dir}/llm-websearch.txt"
         else
            #Save the webpage to a temp file and clean up the HTML tags.
            curl -s -L -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36' "${lurl}" | "${HTML2TEXT_BIN}" > "${temp_dir}/llm-websearch.txt"
         fi
      fi

      #Ask the LLM to check the text for helpful information and summarize it.
      pans=$(llm-python-file.py "${temp_dir}/llm-websearch.txt" "You are a helpful research assistant." "We are trying to research \`${sterm}\` and we have a webpage with the url \`${lurl}\` that has the following text:" "Summarize the portions of the page that help answer \`${sterm}\`.  Only directly summarize the text to help the research and nothing else." "0.7" --rm-think | sed -e 's/\\n/ /g' -e "s/*//g" -e 's/\\//g' | tr '\n' ' ')

       #Error checking the output for page errors like 403.  Commented out because it was being too aggressive, we'll let the last bot filter things until we work that out.
#      echeck=$(llm-python-chat.py "You are an error checking assistant.  You check if the text represents a webpage error or not."  "\`\`\`${pans}\`\`\`\\nOutput only \`PASS\` if the text appears to not be an error, or \`FAIL\` if the text appears to be an error message." "0.0" | sed -e 's/.*content="//g' -e "s/.*content='//g" -e 's/"\, role=.*//g' -e "s/', role=.*//g" -e 's/\\n/ /g' -e "s/*//g" -e 's/\\//g' )
#      if [[ "${echeck}" == *FAIL* ]] ; then
#         continue
#      fi

      #Outputting the info for the user's benefit.
      echo "${lurl} | ${ldesc} | ${pans}"

      #Save the output to an array for later.
      dans+=("${lurl} | ${ldesc} | ${pans}")

   fi

done

#Clear out the old temp file.
echo -n "" > "${temp_dir}/llm-websearch.txt"

#Start looping through the array we created of site info and summaries.
for dan in "${dans[@]}" ; do

   #Echo the website and LLM summary to the temp file.
   echo "${dan}"  >> "${temp_dir}/llm-websearch.txt"

done

#Read the temp file and try to summarize what we've collected in total.  Suggest one URL over all to visit.
llm-python-file.py "${temp_dir}/llm-websearch.txt" "You are a helpful research assistant." "We are trying to research \`${sterm}\` and we have compiled the following list of URLs and their contents." "Try to answer \`${sterm}\` using information from the text.  Provide a total summary of the combined information followed by what you think is the BEST URL source from the list." "0.7" --rm-think | sed -e 's/\\n/ /g' -e "s/*//g" -e 's/\\//g'

