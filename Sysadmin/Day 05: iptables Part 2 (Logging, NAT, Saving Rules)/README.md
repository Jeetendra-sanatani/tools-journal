# 🚫 Sysadmin Day 06: fail2ban (Auto-Blocking Brute-Force Attempts)

<p align="center">
  <img src="https://img.shields.io/badge/sysadmin-day_06-blue?style=for-the-badge" alt="Day 06"/>
  <img src="https://img.shields.io/badge/tool-fail2ban-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> The lab said to ban myself with three wrong passwords. The jail stayed at zero, and that turned out to be the most interesting result of the day: fail2ban is built to protect the admin from exactly this kind of self-inflicted lockout. 🔐

---

## 🏆 Day 05 Recap — iptables Chains, Logging and Saved Rules

Day 05 showed that `ufw` and Docker already own the real `INPUT`/`FORWARD` chains on this machine, that `LOG` only records and never blocks by itself, and that a saved ruleset can be validated safely with `iptables-restore --test`. Today's tool builds on that directly: when fail2ban blocks an IP, the block is just one more firewall chain.

---

## 🎯 Mission Briefing

```
🚫 MISSION: Automate the Brute-Force Investigation
──────────────────────────────────────────
[x] Check the starting state and read the default numbers
[x] Enable the sshd jail through jail.local
[x] Send 3 failed SSH logins and read what the jail counted
[x] Run unbanip and learn what its return value means
──────────────────────────────────────────
STATUS: Sysadmin Day 06 — Done, plus a real discovery about how fail2ban treats localhost
```

---

## ⚡ Quick Theory

**fail2ban is the Linux journal Day 28 investigation, automated.** Instead of manually running `grep "Failed password" | sort | uniq -c`, fail2ban watches a log source, counts failures per IP, and acts when a threshold is crossed.

**Three numbers define a jail.** `maxretry` failures within `findtime` get an IP banned for `bantime`. With the defaults on this machine (`maxretry = 5`, `findtime = 10m`, `bantime = 10m`): 5 failures within 10 minutes means a 10-minute ban.

**Never edit `jail.conf`.** It is overwritten on package updates. Custom settings go in `jail.local`, which fail2ban reads on top of `jail.conf` and merges.

**A ban is a real firewall rule.** With the iptables-based action, fail2ban inserts its own chain (`f2b-<jail>`) and adds one rule per banned IP. On systems configured for nftables, the same rule lives in an nft table instead (`sudo nft list ruleset` shows it).

**The default block type is REJECT.** A banned client gets an immediate "Connection refused" instead of hanging, which is the opposite of the silent `DROP` behaviour from Day 04.

**fail2ban reads the journal.** The status line `Journal matches: _SYSTEMD_UNIT=ssh.service + _COMM=sshd` shows it pulling SSH events straight from the systemd journal, not only from log files.

**`ignoreip` protects the admin.** The shipped default (`ignoreip = 127.0.0.1/8 ::1`) tells fail2ban to never count or ban localhost. Real servers usually add a trusted office or management IP here too.

**Bans survive restarts.** fail2ban keeps its ban history in an SQLite database (usually `/var/lib/fail2ban/fail2ban.sqlite3`) and re-applies bans that haven't expired yet when the service starts again. The firewall rules themselves live in memory, like any iptables rule from Day 05, which is why that re-apply step exists.

**`unbanip` cleans up both sides.** It removes the ban record and the firewall rule together, and returns how many addresses it actually unbanned.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`, working from `~/Desktop/github`)*

### 📋 Step 0 + Part A — Starting state and the default numbers
```bash
$ sudo apt install fail2ban -y
fail2ban is already the newest version (1.1.1-1).
...
Summary:
  Upgrading: 0, Installing: 0, Removing: 0, Not Upgrading: 354

$ sudo fail2ban-client status
2026-10-21 15:53:42,645 fail2ban  [271064]: ERROR  Failed to access socket path: /var/run/fail2ban/fail2ban.sock. Is fail2ban running?
```
fail2ban was already installed, but the service wasn't running, so the client couldn't find its socket. Installing a service is not the same as running it (`sudo systemctl enable --now fail2ban` starts it now and on every boot).

```bash
$ grep -E '^(bantime|findtime|maxretry)' /etc/fail2ban/jail.conf | head -5
bantime  = 10m
findtime = 10m
maxretry = 5
bantime  = 48h
maxretry = 1
```
The first three lines are the global defaults every jail inherits: **ban for 10 minutes, count failures over a 10-minute window, ban after 5 failures.** The last two (`48h`, `1`) aren't defaults. `head -5` kept reading further down the file and caught a different jail's own override, so a plain `grep | head` can't tell global defaults from per-jail settings.

### ⚙️ Part B — Enabling the sshd jail
```bash
$ sudo fail2ban-client status sshd
2026-10-21 15:55:08,754 fail2ban  [272500]: ERROR  Failed to access socket path: /var/run/fail2ban/fail2ban.sock. Is fail2ban running?

$ sudo nano /etc/fail2ban/jail.local
$ sudo systemctl restart fail2ban

$ cat /etc/fail2ban/jail.local
[sshd]
enabled = true
```
Same socket error, because the service still wasn't running. After creating `jail.local` and restarting, the jail came up. This `jail.local` contains **only `enabled = true`**, so the lab's `maxretry = 3` / `findtime = 300` / `bantime = 600` lines were not applied and the defaults (`5` / `10m` / `10m`) stayed in force.

### 🔨 Part C — Sending failed logins
```bash
$ sudo fail2ban-client status sshd
Status for the jail: sshd
├─ Filter
│  ├─ Currently failed: 0
│  ├─ Total failed:     0
│  └─ Journal matches:  _SYSTEMD_UNIT=ssh.service + _COMM=sshd
└─ Actions
   ├─ Currently banned: 0
   ├─ Total banned:     0
   └─ Banned IP list:
```
Jail active, clean slate: 0 failed, 0 banned.

```bash
$ ssh fakeuser@127.0.0.1
fakeuser@127.0.0.1's password:
Permission denied, please try again.
fakeuser@127.0.0.1's password:
Permission denied, please try again.
fakeuser@127.0.0.1's password:
fakeuser@127.0.0.1: Permission denied (publickey,password).

$ sudo fail2ban-client status sshd
Status for the jail: sshd
├─ Filter
│  ├─ Currently failed: 0
│  ├─ Total failed:     0
│  └─ Journal matches:  _SYSTEMD_UNIT=ssh.service + _COMM=sshd
└─ Actions
   ├─ Currently banned: 0
   ├─ Total banned:     0
   └─ Banned IP list:
```
I used a made-up user (`fakeuser`) instead of my real account, a deliberately safer choice for a test meant to get something blocked. Three wrong passwords were sent, SSH rejected all three, and the counters **didn't move**: still 0 failed, 0 banned.

Two separate things explain this:

1. **Why no ban:** the jail ran on the default `maxretry = 5` and only 3 attempts were made. Even if all 3 had been counted, 3 is below 5.
2. **Why not even `Total failed: 3`:** a counted failure would show up in `Total failed` whatever the ban threshold is. The most likely explanation is the shipped `ignoreip` default, which exempts localhost, so failures from my own loopback address are skipped before they are counted. *(Most likely cause, not yet verified on this machine. To check: `sudo fail2ban-client get sshd ignoreip`, and look for an `Ignore 127.0.0.1` line in `sudo grep -i ignore /var/log/fail2ban.log`.)*

### 🔓 Part D — Unbanning
```bash
$ sudo fail2ban-client set sshd unbanip 127.0.0.1
0

$ sudo fail2ban-client status sshd
Status for the jail: sshd
├─ Filter
│  ├─ Currently failed: 0
│  ├─ Total failed:     0
│  └─ Journal matches:  _SYSTEMD_UNIT=ssh.service + _COMM=sshd
└─ Actions
   ├─ Currently banned: 0
   ├─ Total banned:     0
   └─ Banned IP list:
```
The `0` means no address was unbanned, which matches the status output: the banned list was already empty. The command worked as designed; it just had nothing to remove.

---

## 🔬 Reference: What a Successful Ban Looks Like

> ⚠️ **Not from my machine.** These blocks show the typical shape of fail2ban output when a ban does fire, using the documentation IP `192.0.2.10`. They are here as a reference for what to look for, not as my own captured output.

**Jail status after a ban:**
```
Status for the jail: sshd
├─ Filter
│  ├─ Currently failed: 0
│  ├─ Total failed:     3
│  └─ Journal matches:  _SYSTEMD_UNIT=ssh.service + _COMM=sshd
└─ Actions
   ├─ Currently banned: 1
   ├─ Total banned:     1
   └─ Banned IP list:   192.0.2.10
```

**fail2ban's own chain (iptables action):**
```
Chain f2b-sshd (1 references)
 pkts bytes target  prot opt in  out  source        destination
    4   240 REJECT  all  --  *   *    192.0.2.10    0.0.0.0/0   reject-with icmp-port-unreachable
    0     0 RETURN  all  --  *   *    0.0.0.0/0     0.0.0.0/0
```

**The decision in `/var/log/fail2ban.log`:**
```
fail2ban.filter   [PID]: INFO    [sshd] Found 192.0.2.10 - <timestamp>
fail2ban.actions  [PID]: NOTICE  [sshd] Ban 192.0.2.10
fail2ban.actions  [PID]: NOTICE  [sshd] Unban 192.0.2.10
```

**What the banned client experiences:** because the default block type is `REJECT`, a new SSH attempt fails immediately with `Connection refused` instead of hanging until a timeout (the Day 04 DROP-vs-REJECT difference, seen from the client's side).

**After `unbanip`:** the address disappears from the banned list *and* from the `f2b-sshd` chain, so SSH prompts for a password again.

---

## 🧪 What I Actually Found

- [x] fail2ban was installed but **not running**; `fail2ban-client` failed with a socket error until `systemctl restart fail2ban`
- [x] Real defaults on this machine: `maxretry = 5`, `findtime = 10m`, `bantime = 10m`
- [x] `grep | head -5` on `jail.conf` mixed global defaults with another jail's override (`48h`, `maxretry = 1`)
- [x] The `sshd` jail reads from the systemd journal (`_SYSTEMD_UNIT=ssh.service + _COMM=sshd`)
- [x] My `jail.local` had only `enabled = true`, so the lab's `maxretry = 3` was never applied
- [x] 3 failed SSH logins to `127.0.0.1` produced **0 failed, 0 banned** in the jail status
- [x] `unbanip` returned `0` because there was no ban to remove

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: Three Failures, Zero Counted**
> After 3 wrong passwords the jail still showed `Total failed: 0`. The ban threshold alone can't explain that. What can?

<details>
<summary>My answer</summary>

The threshold (`maxretry`) only decides *when a ban happens*; it has nothing to do with whether a failure is counted in the first place. `Total failed: 0` means fail2ban never recorded the three failures at all. The most likely reason is `ignoreip`: the shipped defaults exempt `127.0.0.1`, so failures from my own loopback address are dropped before counting. A second, smaller possibility is timing, since fail2ban polls the journal with a short delay. That's why the next step is to check `fail2ban-client get sshd ignoreip` and the fail2ban log rather than assume.

</details>

> **🥊 Challenge 2: What the Default Numbers Say**
> With `maxretry = 5`, `findtime = 10m`, `bantime = 10m`, describe the rule in one sentence, and say whether my 3 attempts could ever have triggered it.

<details>
<summary>My answer</summary>

The rule is: "if one IP fails 5 times within 10 minutes, block it for 10 minutes." My 3 attempts couldn't have triggered it even if every one had been counted, because 3 is under the limit of 5. The lab's `maxretry = 3` would have, but those lines never made it into my `jail.local`.

</details>

> **🥊 Challenge 3: The Lonely `0`**
> `unbanip 127.0.0.1` printed `0`. Is that an error?

<details>
<summary>My answer</summary>

No. The number is how many addresses were actually unbanned, so `0` means the command ran correctly but found no ban on that IP to remove. That matches the status output right before it, where the banned list was already empty. On a real ban, getting `1` back is a quick confirmation that the removal worked.

</details>

> **🥊 Challenge 4: Reboot Survival**
> If a banned IP's ban is still running and the machine reboots, is the ban lost?

<details>
<summary>My answer</summary>

The firewall rule itself is lost, because plain iptables rules live in memory (Day 05). But fail2ban stores its ban history in an SQLite database on disk and re-applies bans that haven't expired when the service starts again. So the ban comes back after the reboot, for whatever time is left on its `bantime`.

</details>

---

## 🧩 Quick Brain Check

1. Why did `fail2ban-client status` fail with a socket error right after installation?
2. What do `maxretry`, `findtime` and `bantime` mean together in one sentence?
3. Why must custom settings go in `jail.local` and not `jail.conf`?
4. Why could `Total failed` stay at 0 even after 3 wrong SSH passwords?
5. What does `unbanip` returning `0` mean?
6. Why does a banned client get "Connection refused" instead of a hang?

---

## 🐛 Errors / Gotchas I Hit

- **Socket error on `fail2ban-client status`:** the service wasn't running. `systemctl restart fail2ban` fixed it (`systemctl enable --now fail2ban` also makes it start on every boot).
- **`jail.local` was incomplete:** only `enabled = true` was saved. The three tuning lines from the lab were missing, so the defaults applied and the test threshold was 5, not 3.
- **No ban on localhost:** counters stayed at 0 after 3 failed logins, most likely because fail2ban ignores `127.0.0.1` by default. A test that really bans needs the full `jail.local` (`maxretry = 3`) and either a different source address or localhost removed from `ignoreip`.
- **`grep | head -5` is misleading on `jail.conf`:** it mixes the global defaults with per-jail overrides further down the file.

---

## 🔐 Security Relevance

fail2ban turns a manual log investigation into automatic defense, but today showed its safety-first design: it refuses by default to ban localhost, so a misconfigured test can't lock an admin out of their own machine. On a real server the same `ignoreip` list is where a trusted management IP gets added. The flip side for attackers: unlimited password guessing against SSH is exactly what this tool cuts off after a handful of tries, and a short default `bantime` is a speed bump, not a wall, which is why persistent offenders are usually handled with longer ban times.

---

## 🧠 Today's Takeaway

fail2ban follows one simple rule (`maxretry` failures within `findtime` means a `bantime` ban), enforced through a firewall chain it manages itself. Today's real results: the service has to be running, `jail.local` has to contain the numbers you actually want, and localhost is protected by default, so three failed logins to `127.0.0.1` left the jail at zero. That "failure" is the safety feature working.

---

⬅️ [Back to Sysadmin index](../README.md) | ➡️ Next up: **Day 07: logrotate — log rotation & retention**
