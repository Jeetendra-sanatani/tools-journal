# 🧪 Lab Sheet — Sysadmin Day 03: strace (Trace a Program's System Calls)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

**Reminder:** Day 02 (lsof) is still waiting on real `lsof` output — none of the last batch of screenshots actually ran it. Send that first if you can, so the days stay in order.

Every program, no matter the language, eventually asks the kernel to do things: open a file, read it, connect a socket, write output. Those requests are system calls. `strace` shows every single one, in order, as they happen — the lowest level you can watch a program work at without reading its source code.

---

## Step 0: Check it's installed
```bash
which strace
strace -V | head -1
```
Pre-installed on Kali. If missing: `sudo apt install -y strace`

---

## Part A: trace a simple command, start to finish

```bash
# A1 - trace something short and simple
strace ls /tmp

# A2 - same, but save ONLY the syscall summary, not the firehose of lines
strace -c ls /tmp
```
📸 Screenshot: `01-trace-ls.png`

**Note down:**
- In A1's output, find one line containing `openat(` — what file is it opening, and does it look related to something you'd expect `ls` to need?
- In A2's summary table, which syscall was called the MOST times, and roughly what % of total time did it take?

---

## Part B: trace specific categories of syscalls

```bash
# B1 - only file-related syscalls
strace -e trace=open,openat,read,write,close ls /tmp

# B2 - only network-related syscalls (use a command that touches the network)
strace -e trace=network curl -s http://127.0.0.1:8080/ > /dev/null

# B3 - count how many times each syscall happens
strace -c -e trace=network curl -s http://127.0.0.1:8080/ > /dev/null
```
(Part B2/B3 need something listening on 8080 — reuse `python3 -m http.server 8080 &` from Day 02 if it's not already running.)

📸 Screenshot: `02-filtered-trace.png`

**Note down:**
- In B2, can you spot the `connect(` call? What address/port does it connect to?
- Is there a `socket(` call before the `connect(`? What do you think each one does, in plain terms?

---

## Part C: attach to an ALREADY RUNNING process

```bash
# C1 - start something long-running in the background
sleep 300 &
SLEEPPID=$!
echo "PID is $SLEEPPID"

# C2 - attach strace to it by PID (open a SECOND terminal for this, or use tmux - Day 01!)
sudo strace -p <PID-from-above>
# let it run a few seconds, then Ctrl+C to detach (this does NOT kill the process)

# C3 - confirm it's still running after detaching
ps -p <PID-from-above>
kill <PID-from-above>
```
📸 Screenshot: `03-attach-running.png`

**Note down:**
- What (if anything) did strace show while attached to a `sleep` that's just... sleeping?
- Did the process survive you detaching strace with Ctrl+C?

---

## Part D: find out WHY something failed

```bash
# D1 - try to read a file you don't have permission for
sudo touch /root/secret.txt
sudo chmod 600 /root/secret.txt
strace cat /root/secret.txt 2>&1 | tail -5

# D2 - try to open a file that doesn't exist at all
strace cat /tmp/this-file-does-not-exist.txt 2>&1 | tail -5
```
📸 Screenshot: `04-failure-reasons.png`

**Note down:**
- D1 and D2 both make `cat` fail, but for different reasons. What does strace show as the EXACT error for each (look for `= -1 E...`)?
- `cat`'s own error message to the user is similar for both ("Permission denied" vs "No such file or directory") — but is the underlying detail in strace's output actually different? Where?

---

## When you're done

Send me:
1. The screenshots (or a description of what each part showed)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
