#!/bin/python3

import sys
import argparse
# Example: reuse your existing OpenAI setup
from openai import OpenAI
import httpx

parser = argparse.ArgumentParser(description="LLM file processing script")
parser.add_argument("document_file_path", help="Path to the document file")
parser.add_argument("system", help="System prompt")
parser.add_argument("preprompt", help="Pre‑prompt")
parser.add_argument("postprompt", help="Post‑prompt")
parser.add_argument("temp", type=float, help="Temperature")
parser.add_argument("--rm-think", action="store_true", help="Remove <think>...</think> blocks from output")
args = parser.parse_args()

document_file_path = args.document_file_path
system = args.system
preprompt = args.preprompt
postprompt = args.postprompt
temp = args.temp
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
client = OpenAI(base_url="http://localhost:9090/v1", api_key="lm-studio", timeout=httpx.Timeout(7200))

completion = client.chat.completions.create(
  model="gemma-2-2b-it-q8_0",
  messages=[
    {"role": "system", "content": system },
    {"role": "user", "content": preprompt },
    {"role": "user", "content": document },
    {"role": "user", "content": postprompt }
  ],
  temperature=temp,
  stream=True,
)

#print(completion.choices[0].message.content.strip())

if args.rm_think:
    in_think = False          # Are we currently inside a <think> block?
    think_buffer = ""         # Holds partial data when a block is split across chunks.

    for chunk in completion:
        if not (chunk.choices and chunk.choices[0].delta.content):
            continue
        text = chunk.choices[0].delta.content

        # Prepend any leftover from a previous incomplete block.
        if think_buffer:
            text = think_buffer + text
            think_buffer = ""

        idx = 0
        while idx < len(text):
            if not in_think:
                # Look for the next opening or closing tag.
                start_tag = text.find("<think>", idx)
                end_tag = text.find("</think>", idx)

                # Determine which tag appears first.
                if start_tag == -1 and end_tag == -1:
                    # No tags left – output the rest.
                    print(text[idx:], end="", flush=True)
                    break

                # Choose the earliest tag.
                if start_tag != -1 and (end_tag == -1 or start_tag < end_tag):
                    # Opening tag found first.
                    print(text[idx:start_tag], end="", flush=True)
                    idx = start_tag + len("<think>")
                    in_think = True
                    continue
                else:
                    # Closing tag found first (possible think block without opening tag).
                    # Discard everything up to and including the closing tag.
                    idx = end_tag + len("</think>")
                    continue
            else:
                # Currently inside a think block – look for closing tag.
                end = text.find("</think>", idx)
                if end == -1:
                    # Closing tag not found – buffer the rest.
                    think_buffer = text[idx:]
                    break
                # Closing tag found – skip the think block.
                idx = end + len("</think>")
                in_think = False
else:
    for chunk in completion:
        if chunk.choices and chunk.choices[0].delta.content:
            print(chunk.choices[0].delta.content, end="", flush=True)
print('\n')

