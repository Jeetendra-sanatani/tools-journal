# 🧪 Lab Sheet — Sysadmin Day 02: lsof (List Open Files)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

**Before you start:** redo tmux Day 01's Parts B, C and D properly if you haven't yet — detach for real with `Ctrl+b d`, confirm with `echo $TMUX`, then try the window/pane splits again. It's quick and closes that gap.

In Linux, "everything is a file" (Linux journal Day 1) — including network sockets. `lsof` lists every file a process has open RIGHT NOW: real files, directories, and (the part that matters most for troubleshooting) network connections and listening ports.

---

## Step 0: Check it's installed
```bash
which lsof
lsof -v 2>&1 | head -1
```
Pre-installed on Kali. If missing: `sudo apt install -y lsof`

---

## Part A: what's listening on this machine

```bash
# A1 - every process with an open network connection or listening port
sudo lsof -i

# A2 - only things LISTENING (not established connections)
sudo lsof -i -sTCP:LISTEN

# A3 - what's on one specific port
sudo lsof -i :22
```
📸 Screenshot: `01-network-ports.png`

**Note down:**
- Pick 3 lines from A1. For each: what's the COMMAND, PID, and USER?
- Compare A2's list with `ss -tuln` (Linux journal, Day 5) run on the same machine — same ports showing up?

---

## Part B: what has a specific FILE open

```bash
# B1 - pick a file that's definitely in use right now, e.g. a log being written to
sudo lsof /var/log/syslog

# B2 - everything a specific process has open, by PID (use a real PID from ps aux)
ps aux | grep bash
sudo lsof -p <PID-from-above>

# B3 - every file open by a specific program, by NAME instead of PID
sudo lsof -c bash
```
📸 Screenshot: `02-file-and-process.png`

**Note down:**
- In B1, which process(es) had the log file open?
- In B2's output, what do the FD (file descriptor) column values `cwd`, `txt`, and a number like `3u` each mean? (Check `man lsof` or the `-F` legend if unsure.)

---

## Part C: who has a port busy (the troubleshooting use case)

```bash
# C1 - start something listening on a port
python3 -m http.server 8080 &

# C2 - find out what's using it, two ways
sudo lsof -i :8080
sudo fuser 8080/tcp

# C3 - try to start a SECOND thing on the same port (it should fail)
python3 -m http.server 8080

# C4 - clean up: find the PID from C2 and kill it
kill <PID>
sudo lsof -i :8080     # confirm it's gone
```
📸 Screenshot: `03-port-conflict.png`

**Note down:**
- What error did C3 give when the port was already taken?
- `lsof -i :8080` and `fuser 8080/tcp` — did they report the same PID?

---

## Part D: deleted-but-still-open files (a genuinely useful trick)

```bash
# D1 - create a file, open it with something that keeps it open, delete it, check lsof
echo "temporary data" > /tmp/deleteme.txt
tail -f /tmp/deleteme.txt &
TAILPID=$!
rm /tmp/deleteme.txt
ls -la /tmp/deleteme.txt 2>&1        # should say "No such file"
sudo lsof /tmp/deleteme.txt           # but lsof still sees it, marked (deleted)
kill $TAILPID
```
📸 Screenshot: `04-deleted-file.png`

**Note down:**
- Even though `ls` says the file doesn't exist, lsof still shows it. Why does the data still exist on disk if the filename is gone?
- What real-world problem does this trick solve? (Hint: think about log files and disk space that doesn't free up after `rm`.)

---

## When you're done

Send me:
1. The screenshots (or a description of what each part showed)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
