# 🧪 Lab Sheet — Sysadmin Day 07: logrotate (Log Rotation & Retention)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

**Connects back to Linux journal Day 02 (lsof):** that day's "deleted-but-still-open file" trick — where `rm`-ing a file didn't free its disk space because a process still had it open by file descriptor — is exactly the trap `logrotate` is built to avoid. Today you see the correct way to rotate a log a running process is actively writing to.

---

## Step 0: Check it's installed, see what's already managed
```bash
which logrotate
cat /etc/logrotate.conf | head -20
ls /etc/logrotate.d/
```
Pre-installed on most Debian/Kali systems (it runs daily via cron/systemd timer). `/etc/logrotate.d/` holds one config file per service that wants its own rotation rules.

---

## Part A: read a real config

```bash
# A1 - pick any file in /etc/logrotate.d/ and read it (rsyslog or ufw are usually good ones)
cat /etc/logrotate.d/rsyslog
# or, if that's not there:
cat /etc/logrotate.d/ufw

# A2 - find out what the directives actually mean for the ONE config you just read
man logrotate | grep -A 2 "^       rotate\b"
man logrotate | grep -A 2 "^       compress\b"
man logrotate | grep -A 2 "^       missingok\b"
```
📸 Screenshot: `01-real-config.png`

**Note down:**
- Which log file(s) does this config manage, and how many rotated copies does it keep (`rotate N`)?
- Does it use `daily`, `weekly`, or `monthly` rotation? Does it `compress` old logs?
- Is there a `postrotate`/`endscript` block? If so, what command does it run, and why do you think that's needed (hint: think about what happens to a running service's log file handle after rotation)?

---

## Part B: a dry run — see what WOULD happen, safely

```bash
# B1 - debug mode: shows exactly what logrotate would do, without actually doing it
sudo logrotate -d /etc/logrotate.d/rsyslog 2>&1 | head -30

# B2 - same, but for the WHOLE system config (what runs automatically every day)
sudo logrotate -d /etc/logrotate.conf 2>&1 | tail -40
```
📸 Screenshot: `02-dry-run.png`

**Note down:**
- In B1's output, does it say a log file "must be rotated" or does it say it will SKIP rotation? Why (check the file's current size/age against the config's rules)?
- `-d` never actually changes anything on disk. How would you confirm that for yourself after running it?

---

## Part C: build and force-rotate your OWN test log

```bash
# C1 - create a fake "application" that writes to its own log continuously
mkdir -p ~/logrotate-lab
for i in $(seq 1 50); do echo "Log line $i - $(date)" >> ~/logrotate-lab/myapp.log; done
ls -lh ~/logrotate-lab/myapp.log

# C2 - write a logrotate config for it
sudo tee /etc/logrotate.d/myapp-test << 'EOF'
/home/ruin/logrotate-lab/myapp.log {
    size 1k
    rotate 3
    compress
    missingok
    notifempty
    copytruncate
}
EOF
# (adjust the path above if your username isn't ruin)

# C3 - force it to rotate RIGHT NOW (ignoring normal daily/weekly timing)
sudo logrotate -f /etc/logrotate.d/myapp-test

# C4 - see what happened
ls -lh ~/logrotate-lab/
```
📸 Screenshot: `03-forced-rotation.png`

**Note down:**
- What new file(s) appeared in `~/logrotate-lab/` after the forced rotation? What does the `.1` or `.gz` suffix mean?
- Did `myapp.log` itself still exist afterward, or was it replaced? What size is it now?

---

## Part D: why `copytruncate` matters (the lsof connection)

```bash
# D1 - start something that keeps a log file OPEN and keeps writing to it (like a real running service would)
while true; do echo "Still running - $(date)" >> ~/logrotate-lab/myapp.log; sleep 2; done &
WRITERPID=$!

# D2 - confirm it's actually holding the file open
sudo lsof ~/logrotate-lab/myapp.log

# D3 - force another rotation WHILE it's still writing
sudo logrotate -f /etc/logrotate.d/myapp-test

# D4 - watch: does the writer keep appearing in the NEW (rotated) file, or does it vanish?
sleep 5
tail -5 ~/logrotate-lab/myapp.log
sudo lsof ~/logrotate-lab/myapp.log

# D5 - clean up
kill $WRITERPID
sudo rm -f /etc/logrotate.d/myapp-test
rm -rf ~/logrotate-lab
```
📸 Screenshot: `04-copytruncate-in-action.png`

**Note down:**
- After the rotation in D3, did the background writer's NEW log lines show up in the rotated-and-truncated `myapp.log`, or did they go missing / go to a now-invisible old file?
- `copytruncate` COPIES the log then truncates the original to zero length (rather than renaming it). Based on what you saw, why does that specific approach avoid the Linux journal Day 02 "deleted file, process still has the old handle" problem that a plain rename+new-file approach would hit?

---

## When you're done

Send me:
1. The screenshots (or a description of what each part showed)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
