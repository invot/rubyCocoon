"""Asks a local vision model about a screenshot, so checking how something looks doesn't need a person (or a big
model) to look at the picture: it prints the model's short answer.

  python tools/look.py shot.png "List every door and whether furniture blocks it." [max_tokens]

It talks to an OpenAI-style chat server on this machine: by default Bionic's (LM Studio-like) at
http://127.0.0.1:1235 running qwen3-vl-8b-instruct. LOOK_URL and LOOK_MODEL change them. Its answers are quick
(a couple of seconds) but approximate: ask plain, specific questions, and look at the picture yourself when an
answer matters.
"""
import base64
import json
import os
import sys
import urllib.request

URL = os.environ.get("LOOK_URL", "http://127.0.0.1:1235/v1/chat/completions")
MODEL = os.environ.get("LOOK_MODEL", "qwen3-vl-8b-instruct")


def _chat(content, max_tokens):
    body = {"model": MODEL, "temperature": 0.1, "max_tokens": max_tokens,
            "messages": [{"role": "user", "content": content}]}
    req = urllib.request.Request(URL, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=180) as r:
        return json.load(r)["choices"][0]["message"]["content"].strip()


def look(image, question, max_tokens=200):
    data = base64.b64encode(open(image, "rb").read()).decode()
    mime = "image/png" if image.lower().endswith(".png") else "image/jpeg"
    return _chat([{"type": "image_url", "image_url": {"url": "data:%s;base64,%s" % (mime, data)}},
                  {"type": "text", "text": question}], max_tokens)


def ask(text, max_tokens=200):
    """The model's answer to a question with no picture (what a test's log says went wrong, say)."""
    return _chat(text, max_tokens)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    print(look(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 200))
