# Shell Script Web Runner

A tiny Python web server that exposes shell scripts through a friendly browser UI. Pick the script, enter its argument, and the page will show stdout, stderr, and the exit code without leaving your keyboard.

## Project layout

```
.
├── README.md
├── scripts
│   ├── whatsyourdate.sh
│   └── whatsyourname.sh
├── server.py
└── static
    └── index.html
```

## Prerequisites
- Python 3.9+ (ships with macOS) with access to `/bin/bash`
- Executable shell scripts inside the `scripts/` directory (`chmod +x` if needed)

## Run the server

```bash
python3 server.py --host 127.0.0.1 --port 8000
```

Then open `http://127.0.0.1:8000` in your browser. The page loads every `*.sh` file in the `scripts/` folder, lets you choose one, and runs it with the argument you provide. Output appears directly beneath the run button.

## Adding more scripts
1. Drop your script into the `scripts/` directory and ensure it is executable.
2. Expect exactly one positional argument (the value typed into the UI). Update the frontend/backend if you need more inputs.
3. Refresh the webpage—new scripts are listed automatically.

## Notes
- The server uses Python’s `ThreadingHTTPServer`; each request spawns a new subprocess via `/bin/bash`.
- Output is streamed only after the process exits; extend `server.py` if you need live streaming or additional validation.
- For production use, consider authentication and tighter sandboxing, as this setup runs whichever script names appear in the `scripts/` directory.
