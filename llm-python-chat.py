#!/bin/python3

import argparse
import re
# Example: reuse your existing OpenAI setup
from openai import OpenAI
import httpx

parser = argparse.ArgumentParser(description="LLM chat script")
parser.add_argument("system", help="System prompt")
parser.add_argument("prompt", help="User prompt")
parser.add_argument("temp", type=float, help="Temperature")
parser.add_argument("--rm-think", action="store_true", help="Remove <think>...</think> blocks from output")
args = parser.parse_args()

system = args.system
prompt = args.prompt
temp = args.temp

# Point to the local server
client = OpenAI(base_url="http://localhost:9090/v1", api_key="lm-studio", timeout=httpx.Timeout(7200))

# Stream the completion so we can process it chunk‑by‑chunk.
completion = client.chat.completions.create(
  model="gemma-2-2b-it-q8_0",
  messages=[
    {"role": "system", "content": system },
    {"role": "user", "content": prompt }
  ],
  temperature=temp,
  stream=True,
)

# If the user wants to remove <think>...</think> blocks we need to
# detect them even when they span multiple streamed chunks.
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
                    # Remain not in think mode.
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
        # Loop continues to handle multiple tags in the same chunk.
else:
    # No filtering – just stream directly.
    for chunk in completion:
        if chunk.choices and chunk.choices[0].delta.content:
            print(chunk.choices[0].delta.content, end="", flush=True)

# Ensure a final newline after streaming output.
print()
