#!/bin/python3

import re
import sys
from openai import OpenAI

system = sys.argv[1]
prompt = sys.argv[2]
temp = sys.argv[3]

# Point to the local server
client = OpenAI(base_url="http://localhost:9090/v1", api_key="lm-studio")

completion = client.chat.completions.create(
  model="lmstudio-community/gemma-2-2b-it-q8_0",
  messages=[
    {"role": "system", "content": system },
    {"role": "user", "content": prompt }
  ],
  temperature=temp,
)

print(completion.choices[0].message.content.strip())
