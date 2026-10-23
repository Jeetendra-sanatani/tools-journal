# 🧪 Lab Sheet — Sysadmin Day 08: auditd (System Call Auditing)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

`auditd` is the kernel's own "who did what" recorder. Day 03's `strace` watched ONE program's system calls while you ran it; `auditd` watches the whole system, all the time, and writes it to a log. Day 06's fail2ban reacted to failed logins; auditd records *who touched which file*, even if nothing failed.

---

## ⚠️ Scope for today

- Everything below is **read-and-watch only**. You'll watch a file you create yourself, not system files that matter.
- **Never run `auditctl -e 2` today.** It locks the audit configuration until the next reboot, so you couldn't remove your test rules.
- Rules added with `auditctl` live in memory only (like iptables on Day 05). Part D shows how to make them permanent, and how to clean up afterward.
- Services don't always start by themselves after install (Day 06's fail2ban lesson). Step 0 checks that auditd is actually running.
- If `auditctl` or `ausearch` says the command isn't found, or auditd can't run on your setup, tell me what the error says instead of skipping. That's also a valid result.

---

## Step 0: Install, start, check the starting state
```bash
sudo apt install -y auditd
sudo systemctl enable --now auditd
sudo systemctl status auditd --no-pager | head -10
sudo auditctl -s          # status: enabled 1 means the audit system is on
sudo auditctl -l          # list active rules - probably "No rules"
```

---

## Part A: watch a file

```bash
# A1 - create a test file to watch (your own file, not a system one)
mkdir -p /tmp/audit-lab
echo "original content" > /tmp/audit-lab/secret.txt

# A2 - add a watch: -w = path, -p wa = log Writes and Attribute changes, -k = a label (key) to search by
sudo auditctl -w /tmp/audit-lab/secret.txt -p wa -k lab-secret
sudo auditctl -l

# A3 - trigger events: a write, and a permission change
echo "edited by me" >> /tmp/audit-lab/secret.txt
chmod 600 /tmp/audit-lab/secret.txt

# A4 - search the audit log by your key (-i translates numbers like uid/syscall into names)
sudo ausearch -k lab-secret -i | tail -40
```
📸 Screenshot: `01-file-watch.png`

**Note down:**
- How many separate events did your two actions (one write, one `chmod`) produce? What did each look like?
- In one event, which lines do you see (`type=SYSCALL`, `type=PATH`, ...)? Which syscall name was used for the write, and which for the `chmod`?

---

## Part B: read an event properly (and see what sudo does to identity)

```bash
# B1 - write to the same file as root, via sudo
sudo sh -c 'echo "edited as root" >> /tmp/audit-lab/secret.txt'

# B2 - look at the newest event only
sudo ausearch -k lab-secret -i | tail -15

# B3 - compare the two ID fields in that event
sudo ausearch -k lab-secret -i | grep -E "auid=|uid=" | tail -4
```
📸 Screenshot: `02-reading-event.png`

**Note down:**
- In the event from B1, what are `uid` and `auid`? Why are they different when you used `sudo`? (Hint: `auid` is the "audit user ID", set at login and not changed by `sudo` or `su`.)
- Which fields tell you *who* did it, *what program* did it (`comm` / `exe`), and *which file* (`name=` in the PATH record)?

---

## Part C: watch a program being run

```bash
# C1 - watch execution (-p x) of a harmless, common command
which whoami
sudo auditctl -w "$(readlink -f "$(which whoami)")" -p x -k lab-exec

# C2 - run it a couple of times
whoami
whoami

# C3 - find the events
sudo ausearch -k lab-exec -i | tail -25
```
(If `ausearch` finds nothing, check the path from `readlink -f` matches the file in `sudo auditctl -l`.)

**Read-only concept** (don't apply this one, it logs EVERY program started on the machine and gets very noisy):
```bash
# "log every execve system call" - the syscall-rule form, compare it to Day 03's strace -e trace=execve
echo 'sudo auditctl -a always,exit -F arch=b64 -S execve -k all-exec'
```
📸 Screenshot: `03-exec-watch.png`

**Note down:**
- How many events did two `whoami` runs produce? What's different about an `-w ... -p x` watch compared with the syscall rule (`-a always,exit -S execve`) in the concept line?
- Why would logging every `execve` on a busy server be a problem, even though it's powerful?

---

## Part D: reports, log size, and making rules permanent

```bash
# D1 - summary reports
sudo aureport --summary
sudo aureport -k --summary          # events per key - your lab-secret and lab-exec should be listed
sudo aureport -f -i | tail -10      # file events, readable

# D2 - the audit log itself, and its own rotation settings (connects to Day 07 logrotate)
sudo ls -lh /var/log/audit/
grep -E '^(log_file|max_log_file|num_logs|max_log_file_action)' /etc/audit/auditd.conf

# D3 - make a rule permanent: a root-owned file in rules.d (root-owned, Day 07's lesson), loaded by augenrules
sudo tee /etc/audit/rules.d/lab.rules << 'EOF'
-w /tmp/audit-lab/secret.txt -p wa -k lab-secret
EOF
sudo augenrules --load
sudo auditctl -l

# D4 - clean up EVERYTHING from today
sudo auditctl -D                    # delete all active rules
sudo rm -f /etc/audit/rules.d/lab.rules
sudo augenrules --load
sudo auditctl -l                    # should say "No rules" again
rm -rf /tmp/audit-lab
```
📸 Screenshot: `04-reports-and-persist.png`

**Note down:**
- What does `aureport -k --summary` show, and which of your keys had the most events?
- What are `max_log_file` and `num_logs` in `auditd.conf`, and how does auditd's own log rotation compare with a `logrotate` config from Day 07?
- Why does a rule added with plain `auditctl -w` disappear after a reboot, while one in `/etc/audit/rules.d/` doesn't? Which earlier day showed the same "lost on reboot" idea?

---

## When you're done

Send me:
1. The screenshots (or a description of what each part showed)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird, especially if auditd didn't start or `ausearch` found nothing

I'll turn this into the final `README.md`, fill in `Command.txt`, and help you write `Notes.txt`.
