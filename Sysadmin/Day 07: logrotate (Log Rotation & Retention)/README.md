# 🔄 Sysadmin Day 07: logrotate (Log Rotation & Retention)

<p align="center">
  <img src="https://img.shields.io/badge/sysadmin-day_07-blue?style=for-the-badge" alt="Day 07"/>
  <img src="https://img.shields.io/badge/tool-logrotate-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> The lab planned a clean rotation demo. The machine had other ideas: one config that wasn't there, one log file that didn't exist, and a safety check that refused my test config outright. Each of those is a real logrotate rule worth knowing. 🔄

---

## 🏆 Day 06 Recap — fail2ban's Safety Rules

Day 06 showed that a security tool can refuse to do what a lab says, for good reasons: fail2ban ignores localhost by default, so three failed logins never became a ban. Today's tool has the same character. `logrotate` has its own built-in safety rules, and again the most useful lessons came from where the lab didn't go to plan.

---

## 🎯 Mission Briefing

```
🔄 MISSION: Rotate Logs Without Losing a Single Line
──────────────────────────────────────────
[x] Read a real /etc/logrotate.d/ config (ufw, since rsyslog's didn't exist)
[x] Dry run (-d): see what logrotate WOULD do, changing nothing
[x] Forced run (-f): learn that force overrides timing, not existence
[x] Try my own test config: learn why logrotate only trusts root-owned configs
──────────────────────────────────────────
STATUS: Sysadmin Day 07 — Done, with three real logrotate rules discovered the hard way
```

---

## ⚡ Quick Theory

**One config per service.** `/etc/logrotate.conf` holds the global defaults and `/etc/logrotate.d/` holds one file per service that wants its own rules. logrotate runs automatically once a day (via a systemd timer or cron).

**It remembers.** logrotate keeps a state file (`/var/lib/logrotate/status`) recording when each log was last rotated, which is how "weekly" actually works between runs. Both real runs below show it reading that file.

**The key directives:**

| Directive | What it does |
| --- | --- |
| `daily` / `weekly` / `monthly` | How often to rotate |
| `size N` | Rotate once the file reaches this size (a bare number means bytes) |
| `rotate N` | Keep N old copies, delete anything older |
| `compress` / `delaycompress` | gzip old copies / wait one cycle before compressing the newest |
| `missingok` / `notifempty` | Don't error on a missing log / don't rotate an empty one |
| `sharedscripts` | Run `postrotate` once for all matching logs, not once per log |
| `copytruncate` | Copy the log, then truncate the original to zero |
| `postrotate ... endscript` | Commands to run after rotation (usually "reopen your log file") |

**Two ways to rotate a log a process still has open.** Method 1: rename the file, create a new one, then signal the process to reopen it (that is what `postrotate` is for). Method 2: `copytruncate` copies the content out and empties the *same* file, so its inode and the process's open file handle stay valid and no signal is needed.

**Why this matters (Linux journal Day 02, lsof).** A naive "delete the old log and make a new one" leaves the running process writing into an invisible, deleted file while disk space never frees. Both methods above exist to avoid that trap. The one trade-off of `copytruncate`: a few lines written between the copy and the truncate can be lost.

**Three flags to know.** `-d` is a dry run that changes nothing, `-v` prints what it's doing, and `-f` forces a rotation now, ignoring the schedule.

**Only root-owned configs are trusted.** logrotate runs as root and configs can contain scripts, so it ignores config files that aren't owned by root.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`, working from `~/Desktop/github`)*

### 📖 Part A — Reading a real config
```bash
$ cat /etc/logrotate.d/rsyslog
cat: /etc/logrotate.d/rsyslog: No such file or directory

$ cat /etc/logrotate.d/ufw
/var/log/ufw.log
{
        rotate 4
        weekly
        missingok
        notifempty
        compress
        delaycompress
        sharedscripts
        postrotate
                [ -x /usr/lib/rsyslog/rsyslog-rotate ] && /usr/lib/rsyslog/rsyslog-rotate || true
        endscript
}
```
The lab's first choice, `rsyslog`, doesn't exist on this machine, so the fallback `ufw` config was used. Line by line:

- Manages one file: `/var/log/ufw.log`
- `weekly` + `rotate 4`: rotate once a week and keep 4 old copies (about a month of history)
- `compress` + `delaycompress`: gzip old logs, but leave the newest rotated copy uncompressed for one more cycle
- `missingok` + `notifempty`: no error if the log is missing, and don't rotate an empty one
- `sharedscripts`: run the `postrotate` block once, not once per matching file
- `postrotate`: runs rsyslog's helper if it exists (`|| true` stops a missing helper from failing the whole rotation). This implies `ufw.log` is written by rsyslog, which must be told to reopen its log file after rotation. It's the Method 1 pattern from the theory.

### 🔍 Part B — Dry run
```bash
$ sudo logrotate -d /etc/logrotate.d/ufw
warning: logrotate in debug mode does nothing except printing debug messages!  Consider using verbose mode (-v) instead if this is not what you want.

reading config file /etc/logrotate.d/ufw
Reading state from file: /var/lib/logrotate/status
Allocating hash table for state file, size 64 entries
Creating new state
Creating new state
... (about 30 more "Creating new state" lines)

Handling 1 logs

rotating pattern: /var/log/ufw.log weekly empty log files are not rotated, (4 rotations), old logs are removed
considering log /var/log/ufw.log
  log /var/log/ufw.log does not exist -- skipping
not running postrotate script, since no logs were rotated
```
The answer to "must rotate or skip?" is **skip**, and the reason is simple: `/var/log/ufw.log` doesn't exist on this machine, so there was nothing to rotate. `missingok` in the config is why it's a quiet skip rather than an error. The warning at the top is also the proof that `-d` is safe: it "does nothing except printing debug messages."

### ⚡ Part C — Forced rotation
```bash
$ sudo logrotate -vf /etc/logrotate.d/ufw
[sudo] password for ruin:
reading config file /etc/logrotate.d/ufw
acquired lock on state file /var/lib/logrotate/status
Reading state from file: /var/lib/logrotate/status
Allocating hash table for state file, size 64 entries
Creating new state
... (about 30 more "Creating new state" lines)

Handling 1 logs

rotating pattern: /var/log/ufw.log forced from command line empty log files are not rotated, (4 rotations), old logs are removed
considering log /var/log/ufw.log
  log /var/log/ufw.log does not exist -- skipping
not running postrotate script, since no logs were rotated
```
Compared with the dry run, the pattern line now says `forced from command line` instead of `weekly`, so `-f` did override the schedule. But nothing rotated: **force overrides timing, not existence.** Also note the new line `acquired lock on state file`: a real run locks the state file, a dry run doesn't.

### 🧪 Part C/D attempt — my own test config
```bash
$ mkdir -p ~/logrotate-lab
$ echo "Test log entry 1" > ~/logrotate-lab/app.log
$ sudo logrotate -vf -s ~/logrotate-lab/status /dev/stdin <<'EOF'
/home/ruin/logrotate-lab/app.log {
    size 1
    copytruncate
    rotate 2
    missingok
}
EOF
error: Ignoring /dev/stdin because the file owner is wrong (should be root or user with uid 0).
Creating stub state file: /home/ruin/logrotate-lab/status
acquired lock on state file /home/ruin/logrotate-lab/status
Reading state from file: /home/ruin/logrotate-lab/status
Allocating hash table for state file, size 64 entries

Handling 0 logs

$ ls -l ~/logrotate-lab/
total 8
-rw-rw-r-- 1 ruin ruin 17 Oct 21 16:39 app.log
-r-------- 1 root root 29 Oct 21 16:39 status
```
Instead of the lab's `/etc/logrotate.d/myapp-test` file, I fed a config through `/dev/stdin` with a private state file. logrotate refused it: **"Ignoring /dev/stdin because the file owner is wrong (should be root or user with uid 0)."** Result: `Handling 0 logs`, and `app.log` stayed untouched at 17 bytes. The only new file was the `status` state file, created by root with owner-only read permission. This config used `size 1` (1 byte) and `rotate 2`, so it *would* have rotated the 17-byte log had it been accepted.

---

## 🔬 Reference: What a Successful `copytruncate` Rotation Looks Like

> ⚠️ **Not from my machine.** This section describes what the lab's own config (`size 1k`, `rotate 3`, `compress`, `copytruncate`) is designed to produce, as a reference for what to look for. It is not my captured output.

**After a forced rotation of `~/logrotate-lab/myapp.log` (`ls -lh`):**

| File | What to expect |
| --- | --- |
| `myapp.log` | Still exists, **0 bytes**: the original was truncated, not replaced |
| `myapp.log.1.gz` | The rotated copy. `.1` = the most recent rotation (older ones count up: `.2`, `.3`), `.gz` = compressed with gzip |

**With a background writer still running (Part D):**

| Check | What to expect |
| --- | --- |
| `tail -5 myapp.log` after rotation | New "Still running - ..." lines keep appearing in the **same** `myapp.log` |
| `lsof myapp.log` before and after | The **same PID** still holds the file open, and it's the same file (same inode), so nothing was lost |
| Disk space | Nothing is stuck in a deleted-but-open file, which is the Day 02 lsof trap avoided |

**What "must rotate" vs "skip" looks like in `-d` / `-v` output:** for a log that exists, logrotate prints either `log needs rotating` or `log does not need rotating`, based on the schedule or `size` rule and the last-rotated date from the state file. Today's real runs never got that far, because the log didn't exist.

---

## 🧪 What I Actually Found

- [x] `rsyslog`'s logrotate config doesn't exist on this machine; `ufw`'s does (`weekly`, `rotate 4`, `compress`, `delaycompress`, `sharedscripts`, `postrotate`)
- [x] `/var/log/ufw.log` itself doesn't exist, so the dry run and the forced run both ended in `does not exist -- skipping`
- [x] `-f` changed the pattern line from `weekly` to `forced from command line`, but couldn't rotate a file that isn't there
- [x] A real run prints `acquired lock on state file`; the dry run doesn't
- [x] `-d` announces it "does nothing except printing debug messages", which is its own proof it's safe
- [x] logrotate refused a config that wasn't root-owned: `Ignoring /dev/stdin because the file owner is wrong`
- [x] A refused config means `Handling 0 logs`, and `app.log` stayed at 17 bytes

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: Forced, Yet Skipped**
> `-f` means "force rotation now," but the output still said `skipping`. How can a forced rotation skip?

<details>
<summary>My answer</summary>

`-f` only overrides the *decision* part: the weekly schedule and the size check. It can't rotate a file that doesn't exist. The output shows both halves: the pattern line says `forced from command line`, and the next lines say `log /var/log/ufw.log does not exist -- skipping`. Since nothing was rotated, the `postrotate` script was skipped too (`not running postrotate script, since no logs were rotated`).

</details>

> **🥊 Challenge 2: Handling 0 Logs**
> My own config produced `Handling 0 logs` and an error about file ownership. Why does logrotate care who owns its config file?

<details>
<summary>My answer</summary>

logrotate normally runs as root, and a config can contain `postrotate` scripts, which run as root too. If it accepted configs from any user, anyone able to write a config could get commands run as root. So it refuses config files that aren't owned by root (or uid 0). A heredoc piped through `/dev/stdin` is owned by my user, so it was rejected, which is exactly why the lab writes the config with `sudo tee` into `/etc/logrotate.d/`: the file ends up owned by root.

</details>

> **🥊 Challenge 3: Why `copytruncate` Avoids the lsof Trap**
> Explain how `copytruncate` avoids the Day 02 "deleted file, process still has the old handle" problem.

<details>
<summary>My answer</summary>

With rename-based rotation, the running process keeps its open file handle pointing at the old (renamed or deleted) file, so it keeps writing into a file nobody looks at, while disk space doesn't free. `copytruncate` never changes which file the process has open: it copies the contents out and then empties the *same* file, so the inode and the process's handle stay valid and the process just keeps writing into the now-empty log. The trade-off is a tiny window between the copy and the truncate where new lines can be lost, which is why well-behaved services use `postrotate` + reopen instead.

</details>

> **🥊 Challenge 4: Reading a Real Config**
> In one sentence each: what do `rotate 4`, `weekly`, `delaycompress` and `sharedscripts` do in the `ufw` config?

<details>
<summary>My answer</summary>

`weekly` rotates the log once a week; `rotate 4` keeps four old copies and deletes anything older, so roughly a month of history stays on disk; `delaycompress` leaves the newest rotated copy uncompressed for one more cycle (so a process that is still finishing writes to it isn't cut off); `sharedscripts` runs the `postrotate` block once for all matching logs instead of once per log.

</details>

---

## 🧩 Quick Brain Check

1. Why did the dry run say `skipping` for `ufw.log`?
2. What's the difference between `-d`, `-v` and `-f`?
3. What does the `postrotate` block in the `ufw` config do, and why is `|| true` at the end?
4. Why did logrotate refuse `/dev/stdin` as a config file?
5. What does `rotate 4` together with `weekly` mean for how much history is kept?
6. What is the one risk of `copytruncate` compared with rename + signal?

---

## 🐛 Errors / Gotchas I Hit

- **`/etc/logrotate.d/rsyslog` doesn't exist:** the lab's first choice wasn't there, so I used the `ufw` config instead.
- **`/var/log/ufw.log` doesn't exist:** the dry run and the forced run both ended in `skipping`. `-f` can't rotate a file that isn't there.
- **Config via `/dev/stdin` was rejected:** `error: Ignoring /dev/stdin because the file owner is wrong`. The fix is to put the config in a root-owned file with `sudo tee`, as the lab's own step C2 does.
- **A refused config is silent about the log:** the only sign was `Handling 0 logs` and an untouched `app.log`, so always check the error line above it.

---

## 🔐 Security Relevance

Logs are forensic evidence: a sensible `rotate N` keeps weeks of history for an investigation while stopping logs from filling the disk, which is itself a way services get knocked over. The ownership check I ran into is a quiet piece of security design: since logrotate runs as root and configs can run scripts, only root-owned configs are trusted. It's the same instinct as fail2ban ignoring localhost on Day 06: security tools protect the admin from their own shortcuts.

---

## 🧠 Today's Takeaway

logrotate's job is a rotation policy (`weekly`, `rotate 4`, `compress`) plus a rule for processes that still have the log open (`postrotate` or `copytruncate`). Today's real results: `-d` is safe, `-f` forces timing but not existence, and a config only counts if root owns it. Everything else follows from the Day 02 lesson: never leave a running process writing into a file you can no longer see.

---

⬅️ [Back to Sysadmin index](../README.md) | ➡️ Next up: **Day 08: auditd — system call auditing**
