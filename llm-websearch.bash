#!/bin/bash

#Set overall temperature. (Where not explicitly set, ie. 0.0)
temp="0.7"

#Take in a question or search term if user didn't supply it as a parameter.
if [ -z "$1" ]; then
   read -p "What are you searching for?: " sterm
else
   sterm=$*
fi


#Create the search phrase with the LLM.
phrase=$(llm-python-chat.py "You are a Search Engine Assistant. You output the best possible search phrase to help the user find information about their question or research topic. Output ONLY the search phrase they should use and no explanation." "${sterm}" "${temp}" | sed -e 's/\\n//g' -e 's/```//g' -e 's/ /+/g' | tr -d '\n')

#Construct the URL for our SearXNG  I use searx.lan as my LAN address.
url="http://searx.lan/search?q=${phrase}&language=auto&time_range=&safesearch=0&categories=general"

#Show the URL to the user.
echo "${url}"

#Get the websites supplied by SearX.
while [ -z "${links}" ] ; do
   mapfile -t links < <(curl -s "${url}" | htmlq '#urls' | tr -d '\n' | sed -e 's/<article class=/\n/g' | grep "^\"result" )
done

#For each website go through the loop.
for link in "${links[@]}" ; do

   #Save the Link URL
   lurl=$(echo "${link}" | sed -e 's/.*wrapper" href="//g' -e 's/".*//g')

   #Save the Link Description
   ldesc=$(echo "${link}" | sed -e 's/.*class="content">//g' -e 's/<div class="engines".*//g' | htmlq --text | grep -v '^[[:space:]]*$')

   #Ask the LLM if the Description implies the website will help us.  Yes/No.
   ans=$(llm-python-chat.py "You are a helpful research assistant." "We're trying to research \`${sterm}\`. The search engine gave back \`${lurl}\` as a possibility to find out more.  The following is a brief excerpt from the search engine: \`\`\`${ldesc}\`\`\`.  Should we read this page for more information? Always start your answer with \`Yes\` or \`No\`." "${temp}" | sed -e 's/\\n/ /g' -e "s/*//g" -e 's/\\//g' | tr -d '\n')

   #Test if the bot thought the website would be helpful.
   if [[ "${ans}" == Yes* ]] ; then

      #Save the webpage to a temp file and clean up the HTML tags.
      curl -s -L -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36' "${lurl}" | html2text > /tmp/llm-websearch.txt

      #Ask the LLM to check the text for helpful information and summarize it.
      pans=$(llm-python-file.py /tmp/llm-websearch.txt "You are a helpful research assistant." "We are trying to research \`${sterm}\` and we have a webpage with the url \`${lurl}\` that has the following text:" "Summarize the portions of the page that help answer \`${sterm}\`.  Only directly summarize the text to help the research and nothing else." "0.7" | sed -e 's/\\n/ /g' -e "s/*//g" -e 's/\\//g' | tr -d '\n')

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
echo -n "" > /tmp/llm-websearch.txt

#Start looping through the array we created of site info and summaries.
for dan in "${dans[@]}" ; do

   #Echo the website and LLM summary to the temp file.
   echo "${dan}"  >> /tmp/llm-websearch.txt

done

#Read the temp file and try to summarize what we've collected in total.  Suggest one URL over all to visit.
llm-python-file.py /tmp/llm-websearch.txt "You are a helpful research assistant." "We are trying to research \`${sterm}\` and we have compiled the following list of URLs and their contents." "Try to answer \`${sterm}\` using information from the text.  Provide a total summary of the combined information followed by what you think is the BEST URL source from the list." "0.7" | sed -e 's/\\n/ /g' -e "s/*//g" -e 's/\\//g'

