"""Asks a local vision model about a screenshot, so checking how something looks doesn't need a person (or a big
model) to look at the picture: it prints the model's short answer.

  python tools/look.py shot.png "List every door and whether furniture blocks it." [max_tokens]

It also reads text, so a long file or log can be asked about without anyone reading all of it:

  python tools/look.py --ask "Which function places the doors?" scripts/gfx/room_builder.gd [more files] [--max=N]
  git diff | python tools/look.py --ask "Does this change anything about saving?"

The files (or what comes in on stdin when there are none) go to the model with line numbers, so its answer can say
where. Text longer than LOOK_CHARS (100000 characters, about 30k tokens; Bionic loads the model with ~58k of context)
is asked about in parts, and the model then puts the parts' answers together. Reading is slow here (about a minute
per 25,000 characters), and its line numbers can be a few dozen out on long files.

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
CHARS = int(os.environ.get("LOOK_CHARS", "100000"))


def _chat(content, max_tokens):
    body = {"model": MODEL, "temperature": 0.1, "max_tokens": max_tokens,
            "messages": [{"role": "user", "content": content}]}
    req = urllib.request.Request(URL, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return json.load(r)["choices"][0]["message"]["content"].strip()


def look(image, question, max_tokens=200):
    data = base64.b64encode(open(image, "rb").read()).decode()
    mime = "image/png" if image.lower().endswith(".png") else "image/jpeg"
    return _chat([{"type": "image_url", "image_url": {"url": "data:%s;base64,%s" % (mime, data)}},
                  {"type": "text", "text": question}], max_tokens)


def ask(text, max_tokens=200):
    """The model's answer to a question with no picture (what a test's log says went wrong, say)."""
    return _chat(text, max_tokens)


def _parts(paths):
    """The files' numbered lines, cut into pieces of at most CHARS characters; a piece that starts partway through a
    file starts with that file's name again."""
    parts, part, size = [], [], 0
    for path in paths:
        if path == "-":
            name, text = "stdin", sys.stdin.buffer.read().decode("utf-8", "replace")
        else:
            with open(path, encoding="utf-8", errors="replace") as f:
                name, text = path, f.read()
        lines = text.splitlines()
        part.append("=== %s (%d lines) ===" % (name, len(lines)))
        size += len(part[-1]) + 1
        for i, line in enumerate(lines, 1):
            line = "%d: %s" % (i, line[:CHARS // 2])
            if size + len(line) + 1 > CHARS:
                parts.append("\n".join(part))
                part = ["=== %s (continued) ===" % name]
                size = len(part[0]) + 1
            part.append(line)
            size += len(line) + 1
    parts.append("\n".join(part))
    return parts


def ask_files(question, paths, max_tokens=300):
    """The model's answer to a question about some text files ("-" is stdin)."""
    parts = _parts(paths)
    head = ("Answer the question from the text below. Its lines are numbered: say which file and lines when the "
            "answer is about particular lines. Be brief.")
    if len(parts) == 1:
        return _chat("%s\n\nQuestion: %s\n\n%s\n\nQuestion: %s" % (head, question, parts[0], question), max_tokens)
    answers = []
    for i, part in enumerate(parts, 1):
        answer = _chat("%s This is part %d of %d of the text; if this part has nothing to do with the question, "
                       "answer only: nothing.\n\nQuestion: %s\n\n%s\n\nQuestion: %s"
                       % (head, i, len(parts), question, part, question), max_tokens)
        if answer.strip().strip(".").lower() != "nothing":
            answers.append("Part %d: %s" % (i, answer))
    if not answers:
        return "nothing"
    if len(answers) == 1:
        return answers[0].split(": ", 1)[1]
    return _chat("A long text was asked about in parts. Put these answers from its parts together into one brief "
                 "answer, keeping the file names and line numbers.\n\nQuestion: %s\n\n%s"
                 % (question, "\n\n".join(answers)), max_tokens)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if len(sys.argv) > 2 and sys.argv[1] == "--ask":
        rest = sys.argv[3:]
        limit = [int(a.split("=", 1)[1]) for a in rest if a.startswith("--max=")]
        print(ask_files(sys.argv[2], [a for a in rest if not a.startswith("--max=")] or ["-"],
                        limit[-1] if limit else 300))
        sys.exit(0)
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    print(look(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 200))
