# llm-websearch
My version of an LLM Websearch Agent using a local SearXNG server because SearXNG is great.

## The Search Process

1. It fetches the first page of results from the general SearXNG search.  This can be about 30 results.

2. It then iterates over each page description from SearXNG to decide if it wants to investigate the page.

3. If it does think the description is interesting then it uses cURL to fetch the page and try to make an LLM summary of the information we need.  It simply stores this in a text file. ( /tmp/llm-websearch.txt )

4. At the end of the SearXNG URL results it attempts to examine the text file it has created to make yet another summary of the information.

The list of sources and the summary can be useful for research.

It's just a hacked together mess.  Assume it has bugs.  The LLM may also decide to hallucinate at any given point in the process.

## SearXNG
SearXNG should be a friendly solution as an open source search option.  The `docker-compose` ( [https://github.com/searxng/searxng-docker](https://github.com/searxng/searxng-docker) ) was the easiest way for me to spin up a local server.

I have mine hosted at a LAN address of http://searx.lan which is used in the `llm-webserver.bash` script.  Change this to your local address of your SearXNG server.

## The Local LLM
I have mine hosted at localhost, port 9090.  Change this in both the python scripts for your needs.

I've been using Gemma 2 2B Q8, results may vary with other LLM.

## Misc
Otherwise, I just have the three scripts (two python, one bash) in my /usr/local/bin PATH in linux.  I'm specifically in Ubuntu if there are any 'Ubuntuisms'.
