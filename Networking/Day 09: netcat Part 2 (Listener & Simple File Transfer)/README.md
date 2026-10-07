# 📁 Networking Day 09: netcat Part 2 (Listener & Simple File Transfer)

<p align="center">
  <img src="https://img.shields.io/badge/networking-day_09%2F15-blue?style=for-the-badge" alt="Day 09"/>
  <img src="https://img.shields.io/badge/tool-netcat-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black%2Flocal_only-black?style=for-the-badge" alt="Lab"/>
</p>

> Day 08 tested ports and grabbed banners. Day 09 uses the same listener mechanism for something more concrete: moving an actual file between two machines, no extra tools required. 📁

---

## 🏆 Day 08 Recap — Challenge Solutions

**Challenge 1 (Refused, Then Open):** The listener wasn't running yet on the first attempt — "Connection refused" means the OS actively rejected the SYN because nothing was listening, unlike a timeout where nothing responds at all.

**Challenge 2 (The Mystery Characters):** A raw netcat session has no readline/line-editing — the up-arrow's escape sequence just gets sent and echoed back as literal bytes.

**Challenge 3 (Same Answer, Simpler Tool):** netcat is precise for one connection; nmap scales across many ports and hosts with automated probing.

---

## 🎯 Mission Briefing

The same `-lvnp` listener from Day 08 can do more than chat — redirect its output into a file, and you have a receiver. Redirect a file's content into a connection, and you have a sender. No FTP server, no special protocol, just raw TCP and shell redirection.

```
📁 MISSION: Move Data Through a Raw Connection
──────────────────────────────────────────
[x] Transfer a real file between two terminals
[x] Verify the transferred file matches exactly
[x] Confirm two-way chat still works as the underlying mechanism
──────────────────────────────────────────
STATUS: Networking Day 09 — Done
```

---

## ⚡ Quick Theory

**File transfer with netcat is just redirection applied to a TCP connection:**
```
receiver:  nc -lvnp <port> > output_file     (whatever arrives gets written to a file)
sender:    nc <receiver-ip> <port> < input_file   (the file's contents get piped in)
```
There's no protocol here in the usual sense — no checksums, no resume support, no encryption, no progress indicator. It's the network equivalent of `cat file > /dev/tcp_connection`. That simplicity is also its biggest limitation compared to a real transfer tool like `scp`/`rsync` (Day 20 of the Linux journal), which add integrity checks, resumability, and encryption on top of this same basic idea.

**A netcat listener receiving a file doesn't automatically know when the file is "done."** Unlike a real protocol with an explicit end-of-transfer signal, a plain `nc -lvnp` listener keeps waiting after the data stops arriving — it has to be manually interrupted (Ctrl+C) once the transfer is actually finished, or started with a flag like `-q` that adds an automatic timeout after the connection goes idle.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`, two terminals)*

### 📤 File transfer
```bash
$ mkdir -p ~/nc-lab && cd ~/nc-lab
$ echo "Netcat file transfer practice" > test.txt
$ ls -lh test.txt
-rw-rw-r-- 1 ruin ruin 30 Oct  6 12:18 test.txt

$ nc -lvnp 4444 > received.txt
listening on [any] 4444 ...
connect to [127.0.0.1] from (UNKNOWN) [127.0.0.1] 46230
^C
```
```bash
$ cd ~/nc-lab
$ nc 127.0.0.1 4444 < test.txt
```
```bash
$ ls -lh received.txt
-rw-rw-r-- 1 ruin ruin 30 Oct  6 12:18 received.txt

$ cat received.txt
Netcat file transfer practice
```
The file transferred successfully — `received.txt` matches `test.txt` exactly, both in content (`cat` shows identical text) and size (30 bytes on both sides). Note the `^C` on the listener: after the transfer completed, netcat didn't close the connection on its own — it had to be manually interrupted once the file was fully received.

### 💬 Two-way chat (confirming the underlying mechanism)
```bash
$ nc -lvnp 4444
listening on [any] 4444 ...
connect to [127.0.0.1] from (UNKNOWN) [127.0.0.1] 46806
Hello from Terminal 2
Hello from Terminal 1
```
```bash
$ nc 127.0.0.1 4444
Hello from Terminal 2
Hello from Terminal 1
```
Ran successfully twice across two separate sessions — confirming the same listener/connect pair that moved a file above is really just a bidirectional pipe underneath; a file transfer and a chat session use the exact same mechanism, just with different input/output redirected into it.

---

## 🧪 What I Actually Found

- [x] File transfer: `received.txt` matched `test.txt` exactly (content + size)
- [x] Listener required a manual Ctrl+C after the transfer — no automatic end-of-transfer signal
- [x] Two-way chat confirmed the listener/connect mechanism works bidirectionally
- [ ] Shell-via-`-e` demo (Part A) — attempted but not clearly captured this round; revisiting next time

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: No Automatic Stop**
> The file transfer worked, but the listener had to be manually stopped with Ctrl+C afterward. What real feature is missing here compared to a proper file transfer protocol, and why does that matter for larger files?

<details>
<summary>My answer</summary>

There's no explicit "end of file" signal in this setup — the listener has no way to know the sender is actually done versus just paused. For a small test file this is a minor annoyance (just Ctrl+C once it's clearly finished), but for a large file, there's no way to confirm the transfer is complete without separately checking the file size/checksum against the original, and no resume capability if the connection drops partway through.

</details>

> **🥊 Challenge 2: Verifying, Not Assuming**
> `cat received.txt` showed the expected content, and `ls -lh` showed matching file sizes. Why check BOTH instead of just one?

<details>
<summary>My answer</summary>

Matching sizes alone wouldn't catch content corruption where bytes get swapped but the total count stays the same (rare, but possible). Matching content alone (via `cat`) is fine for a tiny text file I can read by eye, but wouldn't scale to a large binary file where I can't visually verify every byte. Together, they give reasonable confidence; for anything important, a proper checksum (`md5sum`/`sha256sum`) would be the real verification step.

</details>

> **🥊 Challenge 3: Same Tool, Different Job**
> The exact same `nc -lvnp` / `nc <ip> <port>` pair was used for both the chat demo and the file transfer. What's the ONLY thing that actually changed between the two uses?

<details>
<summary>My answer</summary>

Just what was redirected in and out of the connection. For chat, both ends were connected to the terminal (typed input, displayed output) with nothing redirected. For file transfer, the receiver's output was redirected into a file (`> received.txt`) and the sender's input came from a file instead of the keyboard (`< test.txt`). netcat itself didn't change at all — only the redirection around it did.

</details>

---

## 🧩 Quick Brain Check

1. What's actually happening when you run `nc -lvnp 4444 > received.txt`?
2. Why doesn't the listener automatically stop once a file transfer finishes?
3. What real protocol features (that scp/rsync have) does this simple netcat method lack?
4. If you wanted to verify a large transferred file is byte-for-byte identical to the original, what command would you reach for instead of just comparing file sizes?
5. What's the single conceptual difference between using netcat for chat versus using it for file transfer?

---

## 🐛 Errors / Gotchas I Hit

- The file-receiving listener (`nc -lvnp 4444 > received.txt`) didn't close on its own after the transfer finished — had to manually press Ctrl+C once the file was clearly fully received.
- The shell-via-`-e` demo (Part A) wasn't clearly captured this session — worth revisiting to confirm whether this `nc` build supports `-e` at all, since many modern builds remove it specifically to reduce abuse potential.
- Screenshot naming didn't perfectly match which lab part each one showed (two ended up documenting the chat demo rather than one chat + one shell test) — content itself is accurate, just worth double-checking screenshot labels match the actual command run next time.

---

## 🔐 Security Relevance

This exact file-transfer trick — a listener piped into a file, a sender piped from a file — is a real technique used to move tools or exfiltrate data on a compromised system when no other transfer method is available (no scp, no shared drive, just raw network access). Recognizing an unexpected listening port receiving a large inbound transfer is exactly the kind of signal a defender watches for; the Linux journal's `ss -tuln` and process-monitoring days are directly relevant here.

---

## 🧠 Today's Takeaway

File transfer over netcat is just the Day 08 listener/connect pair with input and output redirected instead of typed — no new mechanism, only a different use of the same one. It works, but lacks everything a real transfer protocol provides: integrity checks, resumability, and a clean end signal. Verifying both size AND content matters more than trusting either alone.

---

⬅️ [Back to Networking index](../README.md) | ➡️ Next up: **Day 10: tcpdump Part 1 — packet capture basics**
