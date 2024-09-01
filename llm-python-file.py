#!/bin/python3

import sys
from openai import OpenAI

document_file_path = sys.argv[1]
system = sys.argv[2]
preprompt = sys.argv[3]
postprompt = sys.argv[4]
temp = sys.argv[5]
# Read the content of the document file
try:
    with open(document_file_path, 'r') as file:
        document = file.read()
except FileNotFoundError:
    print(f"Error: The file '{document_file_path}' does not exist.")
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)


# Point to the local server
client = OpenAI(base_url="http://localhost:9090/v1", api_key="lm-studio")

completion = client.chat.completions.create(
  model="lmstudio-community/gemma-2-2b-it-q8_0",
  messages=[
    {"role": "system", "content": system },
    {"role": "user", "content": preprompt },
    {"role": "user", "content": document },
    {"role": "user", "content": postprompt }
  ],
  temperature=temp,
)

print(completion.choices[0].message.content.strip())
