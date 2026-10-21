# 🧪 Lab Sheet — Sysadmin Day 06: fail2ban (Auto-Blocking Brute-Force Attempts)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

This is what Linux journal Day 28's manual `grep "Failed password" auth.log | sort | uniq -c` investigation looks like automated: `fail2ban` watches a log for a pattern, counts failures per IP, and when a threshold is crossed within a time window, it adds a firewall rule (using `iptables`, which you now actually understand from Days 04-05) to block that IP.

---

## ⚠️ Scope for today

- Test ONLY against SSH on your own machine, connecting to `127.0.0.1` from the SAME machine. Never test against a remote server or a connection you actually need to stay open.
- Before triggering a real ban (Part C), know the unban command (`fail2ban-client set sshd unbanip <ip>`) — you'll need it on yourself in a few minutes.
- This machine already runs `ufw` and Docker's own iptables chains (Days 04-05) — fail2ban adds ANOTHER chain on top (`f2b-sshd`). Expect `iptables -L` to get even busier today, and that's expected, not a conflict.

---

## Step 0: Install and check the starting state
```bash
sudo apt install -y fail2ban
sudo systemctl status fail2ban
sudo fail2ban-client status
```

---

## Part A: understand the default config (read before touching)

```bash
# A1 - the shipped defaults - NEVER edit this file directly, it gets overwritten on updates
cat /etc/fail2ban/jail.conf | grep -A 15 "^\[sshd\]"

# A2 - the global defaults every jail inherits unless overridden
cat /etc/fail2ban/jail.conf | grep -E "^(bantime|findtime|maxretry)" | head -5

# A3 - what filter does the sshd jail actually use to RECOGNIZE a failed login?
cat /etc/fail2ban/filter.d/sshd.conf | grep -A 5 "^failregex"
```
📸 Screenshot: `01-default-config.png`

**Note down:**
- What are the default `bantime`, `findtime`, and `maxretry` values? In plain English, what rule do these three numbers together describe?
- `jail.conf` says not to edit it directly — where SHOULD custom settings go instead? (Check the top of the file for a comment about this.)

---

## Part B: enable the sshd jail properly

```bash
# B1 - create (don't edit jail.conf) a local override file
sudo tee /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
maxretry = 3
findtime = 300
bantime = 600
EOF

# B2 - restart to pick up the new config
sudo systemctl restart fail2ban

# B3 - confirm the jail is active
sudo fail2ban-client status
sudo fail2ban-client status sshd
```
📸 Screenshot: `02-jail-enabled.png`

**Note down:**
- What does `fail2ban-client status sshd` show BEFORE any failed attempts — what are the "Currently failed" and "Currently banned" counts?
- Why `maxretry = 3` here instead of the default — what tradeoff does a LOWER number make (security vs convenience)?

---

## Part C: trigger a real ban (on yourself, on purpose)

```bash
# C1 - make SURE sshd is actually running and reachable on localhost first
sudo systemctl status ssh
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no ruin@127.0.0.1
# (type a WRONG password 3 times in a row, on purpose, then let it give up)

# C2 - check the jail noticed
sudo fail2ban-client status sshd

# C3 - try connecting again - it should be refused/timeout now
ssh -o ConnectTimeout=5 ruin@127.0.0.1

# C4 - see fail2ban's OWN chain in iptables
sudo iptables -L -n -v | grep -A 5 f2b-sshd

# C5 - see the actual log entries fail2ban made its decision from
sudo tail -20 /var/log/fail2ban.log
```
📸 Screenshot: `03-triggered-ban.png`

**Note down:**
- After the 3 wrong passwords, what did `fail2ban-client status sshd` show for "Currently banned" and the banned IP list?
- What does C3's connection attempt actually do - hang, refuse immediately, or something else? Compare to Day 04's DROP vs REJECT distinction.
- In `/var/log/fail2ban.log`, find the line where it actually issued the ban - what does it say?

---

## Part D: unban yourself and understand persistence

```bash
# D1 - unban
sudo fail2ban-client set sshd unbanip 127.0.0.1

# D2 - confirm you're unbanned both ways
sudo fail2ban-client status sshd
ssh -o ConnectTimeout=5 ruin@127.0.0.1    # should prompt for a password again now

# D3 - confirm the iptables rule is gone too
sudo iptables -L -n -v | grep -A 5 f2b-sshd
```
📸 Screenshot: `04-unbanned.png`

**Note down:**
- Did unbanning via `fail2ban-client` also clean up the `iptables` rule automatically, or did you have to check separately?
- What would happen to an active ban if you rebooted the machine right now — does fail2ban remember bans across a restart, or does the ban list reset? (Check `/etc/fail2ban/jail.local`'s `bantime` setting and think about where ban state is actually stored — in memory, or on disk.)

---

## When you're done

Send me:
1. The screenshots (or a description of what each part showed)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
