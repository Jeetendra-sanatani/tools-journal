# 🧪 Lab Sheet — Sysadmin Day 10: Capstone — Mini Server Hardening & Audit

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

This is the last day of the Sysadmin phase. No new tool today: you use the ones you already know, in one flow, the way a sysadmin actually would on a server. The question for the whole day: **"What's exposed, what defends it, who's watching, and is it housekept?"**

| Question | Tool | From |
| --- | --- | --- |
| What's listening? | `ss`, `lsof` | Day 02 |
| What blocks it? | `ufw` / `iptables` (read only) | Day 04-05 |
| What stops brute force? | `fail2ban` | Day 06 |
| Who's watching changes? | `auditd` | Day 08 |
| Will logs and disk stay healthy? | `logrotate`, `ncdu`, `df` | Day 07, 09 |
| Where do I run all this? | `tmux` | Day 01 |

---

## ⚠️ Scope for today

- **No firewall changes.** Your machine already runs `ufw` and Docker's own rules (Day 04-05). Today you *read* the firewall; you don't apply a new default-DROP script.
- **The fail2ban test uses a fake address.** `192.0.2.10` is a reserved documentation address (it belongs to no real machine or person), and you ban it by hand. That avoids Day 06's localhost problem, where fail2ban ignores `127.0.0.1` by design.
- Every test rule or file has a clean-up line. Do the clean-up at the end of each part, not at the very end.
- If something isn't installed or doesn't run, send me the error. That's a valid result, same as on Days 06 and 07.

---

## Step 0: Pre-flight and a tmux workspace
```bash
# are the services from earlier days actually running? (Day 06's lesson: installed is not the same as running)
systemctl is-active ssh auditd fail2ban
command -v tmux ncdu

# start what's missing
sudo systemctl enable --now auditd fail2ban

# one tmux session for the whole capstone (Day 01); split a second pane with Ctrl-b then %
tmux new -s capstone
```
Keep the second pane free for `sudo tail -f /var/log/fail2ban.log` in Part B.

---

## Part A: inventory — what's exposed? (read only)

```bash
# A1 - everything listening, with the owning program
sudo ss -tulpn

# A2 - the same idea through lsof (Day 02)
sudo lsof -i -P -n | grep LISTEN

# A3 - the firewall, read only
sudo ufw status verbose
sudo iptables -S | head -20
```
📸 Screenshot: `01-inventory.png`

**Note down:**
- Which ports are listening, and for each: is it expected, and is it reachable from outside (`0.0.0.0` / `*`) or only from the machine itself (`127.0.0.1`)?
- Is `ufw` active? What is the default incoming policy? (Day 05 showed `INPUT` already defaulted to DROP.)
- Do any listening ports belong to Docker (`docker-proxy`)? What would you check before exposing them?

---

## Part B: brute-force defense — a real ban, the safe way (finishes Day 06)

```bash
# B1 - make sure the sshd jail has the full settings (shows what's there now)
cat /etc/fail2ban/jail.local

# B2 - if maxretry/findtime/bantime are missing, set them (root-owned file via sudo tee, Day 07's lesson)
sudo tee /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
maxretry = 3
findtime = 300
bantime = 600
EOF
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd

# B3 - in the SECOND tmux pane, watch fail2ban's own log live
sudo tail -f /var/log/fail2ban.log
#   (if that file doesn't exist: sudo journalctl -u fail2ban -f)

# B4 - ban the fake documentation address by hand
sudo fail2ban-client set sshd banip 192.0.2.10
sudo fail2ban-client status sshd

# B5 - the firewall rule fail2ban created (use whichever one shows a result)
sudo iptables -L -n -v | grep -A 5 f2b-sshd
sudo nft list ruleset | grep -B 3 -A 6 f2b

# B6 - unban and confirm it's gone from both places
sudo fail2ban-client set sshd unbanip 192.0.2.10
sudo fail2ban-client status sshd
sudo iptables -L -n -v | grep -A 5 f2b-sshd
```
📸 Screenshot: `02-fail2ban-ban.png` (status after the ban, the firewall rule, and the log line; use two screenshots if needed)

**Note down:**
- After B4, what does `Currently banned` / `Banned IP list` show? What is the firewall rule's target (`REJECT`, `DROP`)?
- Which line in the fail2ban log records the ban and the unban?
- What number did `unbanip` print this time, and how does it compare with the `0` on Day 06?

---

## Part C: audit trail — who touches my security config? (Day 08)

```bash
# C1 - watch the fail2ban config file for writes and attribute changes
sudo auditctl -w /etc/fail2ban/jail.local -p wa -k f2b-config
sudo auditctl -l

# C2 - trigger an event (re-applies the normal permissions, changes nothing else)
sudo chmod 644 /etc/fail2ban/jail.local

# C3 - read it back
sudo ausearch -k f2b-config -i | tail -20

# C4 - clean up this one watch (-W removes a watch rule)
sudo auditctl -W /etc/fail2ban/jail.local -p wa -k f2b-config
sudo auditctl -l
```
📸 Screenshot: `03-audit-config-watch.png`

**Note down:**
- In the event: which syscall, which `uid` and `auid`, which `comm`/`exe`, and which file?
- If someone edited `jail.local` to remove protection, would this event tell you who did it, even if they used `sudo`? Which field answers that?

---

## Part D: housekeeping — will it stay healthy? (Day 07 + 09)

```bash
# D1 - do the logs from today's tools have rotation rules?
ls /etc/logrotate.d/ | grep -E 'audit|fail2ban|ufw|rsyslog'
cat /etc/logrotate.d/fail2ban 2>/dev/null || echo "no fail2ban logrotate config found"

# D2 - dry run it (changes nothing)
sudo logrotate -d /etc/logrotate.d/fail2ban 2>&1 | tail -15

# D3 - how big are today's logs, and how healthy is the disk?
sudo du -sh /var/log/audit /var/log/fail2ban.log /var/log/journal 2>/dev/null
df -h / | tail -1

# D4 - look at /var/log with ncdu, READ-ONLY (-r), one filesystem (-x)
sudo ncdu -r -x /var/log
```
📸 Screenshot: `04-housekeeping.png` (D2/D3 output, and ncdu on screen if you can)

**Note down:**
- Does fail2ban's log have a logrotate config? How many copies does it keep, how often does it rotate, does it compress?
- auditd rotates its own log: how is that different from a `logrotate` config?
- What is the biggest thing in `/var/log`, and how much free space does `/` have?

---

## Part E (bonus, optional): finish Day 07's copytruncate demo

Day 07's own-config test was rejected (the config wasn't root-owned). This version fixes that, and adds the `su` line that logrotate needs when the log lives in a folder your user owns.

```bash
# E1 - a log with some content
mkdir -p ~/logrotate-lab
for i in $(seq 1 50); do echo "Log line $i - $(date)" >> ~/logrotate-lab/myapp.log; done

# E2 - root-owned config (sudo tee); $HOME and $USER expand in your shell before sudo runs
sudo tee /etc/logrotate.d/myapp-test << EOF
$HOME/logrotate-lab/myapp.log {
    su $USER $USER
    size 1k
    rotate 3
    compress
    missingok
    notifempty
    copytruncate
}
EOF

# E3 - a writer that keeps the file open, plus proof of it
while true; do echo "Still running - $(date)" >> ~/logrotate-lab/myapp.log; sleep 2; done &
WRITERPID=$!
sudo lsof ~/logrotate-lab/myapp.log

# E4 - force rotation WHILE it's writing
sudo logrotate -vf /etc/logrotate.d/myapp-test
ls -lh ~/logrotate-lab/
sleep 5
tail -5 ~/logrotate-lab/myapp.log
sudo lsof ~/logrotate-lab/myapp.log

# E5 - clean up
kill $WRITERPID
sudo rm -f /etc/logrotate.d/myapp-test
rm -rf ~/logrotate-lab
```
📸 Screenshot: `05-copytruncate-demo.png`

**Note down:**
- What files exist after the rotation, and how big is `myapp.log` right after?
- Did the writer's new lines keep appearing in `myapp.log`? Was it the same PID holding the file before and after?

---

## Part F: the hardening scorecard (the deliverable)

Fill this in with one honest line of evidence per row, using your own outputs from Parts A to E:

| Area | Tool (day) | Status (OK / needs work) | Evidence in one line |
| --- | --- | --- | --- |
| Exposed ports | ss / lsof (02) | | |
| Firewall | ufw / iptables (04-05) | | |
| Brute-force defense | fail2ban (06) | | |
| Audit trail | auditd (08) | | |
| Log retention | logrotate (07) | | |
| Disk health | ncdu / df (09) | | |
| Workflow | tmux (01) | | |

Then answer in two sentences: **what is the single weakest spot on this machine, and what is the first thing you would fix?**

---

## When you're done

Send me:
1. The screenshots (or a description of what each part showed)
2. Your answers to the "note down" questions above, and your scorecard
3. Anything that errored or looked weird

I'll turn this into the final `README.md` (including a Phase 2 wrap-up), fill in `Command.txt`, and help you write `Notes.txt`. Next up is Phase 3: Pentesting.
