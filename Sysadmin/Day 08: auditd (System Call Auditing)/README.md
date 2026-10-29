# 👁️ Sysadmin Day 08: inotifywait (Real-Time File Monitoring)

<p align="center">
  <img src="https://img.shields.io/badge/sysadmin-day_08-blue?style=for-the-badge" alt="Day 08"/>
  <img src="https://img.shields.io/badge/tool-inotify--tools-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> Day 07 kept log files from growing forever. Today's question is the next one up: **how do I know the moment a file is read, changed or run?** The kernel can tell you, live, one line per event. 👁️

---

## 🏆 Day 07 Recap — logrotate

Day 07 showed that `logrotate` rotates logs on a schedule, that `-f` forces timing but not existence, and that it only trusts root-owned configs. Those logs and config files are exactly the kind of files worth watching, which is what today is about.

---

## 🎯 Mission Briefing

```
👁️ MISSION: Watch Files Change in Real Time
──────────────────────────────────────────
[x] Install inotify-tools and confirm it's ready
[x] Watch a file while another terminal writes to it
[x] Watch the same file being read
[x] Watch a script file being run
[x] Save the watch output to a report file
──────────────────────────────────────────
STATUS: Sysadmin Day 08 — Done
```

---

## ⚡ Quick Theory

**inotify is a Linux kernel feature.** A program says "tell me when something happens to this file," and the kernel sends an event every time it does. `inotify-tools` gives two command-line programs for it, and the main one is `inotifywait`.

**Event names, as seen in today's output:**

| Event | What caused it |
| --- | --- |
| `OPEN` | a program opened the file |
| `ACCESS` | the file's content was read |
| `MODIFY` | the file's content was written to |
| `CLOSE_WRITE` | the file was closed after being open for writing |
| `CLOSE_NOWRITE` | the file was closed after being open for reading only |
| `CLOSE` | shown alongside either close event |

**Three options used today:**

| Option | Meaning |
| --- | --- |
| `-m` | monitor: keep running and print every event (without it, `inotifywait` exits after the first one) |
| `-e a,b,c` | only report these event types |
| `> file 2>&1` | not an inotifywait option but a shell redirect: save everything it prints, errors included, to a file |

**What inotify does NOT tell you.** An event says *what* happened to *which file*, but not *who* did it or *which program*. That is the gap that `auditd` (system call auditing) fills with user IDs and executable names, and it keeps its records in a log instead of on your screen.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`. Each part uses two terminals: ① runs the watcher, ② does something to the file.)*

### 📦 Step 0 — Install
```bash
$ sudo apt install inotify-tools -y
inotify-tools is already the newest version (4.25.9.0-1+b1).
...
Summary:
  Upgrading: 0, Installing: 0, Removing: 0, Not Upgrading: 354
```
Already installed, nothing to do.

### ✍️ Part A — Watching writes
```bash
# Terminal 1 (before watching): create the file
$ echo "First entry" > ~/watch.txt

# Terminal 1: watch it
$ inotifywait -m ~/watch.txt
Setting up watches.
Watches established.

# Terminal 2: three appends
$ echo "New entry" >> ~/watch.txt
$ echo "New entry" >> ~/watch.txt
$ echo "OLD entry" >> ~/watch.txt
```
What terminal 1 printed:
```
/home/ruin/watch.txt OPEN
/home/ruin/watch.txt MODIFY
/home/ruin/watch.txt CLOSE_WRITE,CLOSE
/home/ruin/watch.txt OPEN
/home/ruin/watch.txt MODIFY
/home/ruin/watch.txt CLOSE_WRITE,CLOSE
/home/ruin/watch.txt OPEN
/home/ruin/watch.txt MODIFY
/home/ruin/watch.txt CLOSE_WRITE,CLOSE
```
Three `echo ... >>` commands gave three identical sequences: **open, modify, close-after-write.** The `echo "First entry" > ~/watch.txt` that created the file isn't in the output, because it ran before the watch started.

### 📖 Part B — Watching reads
```bash
# Terminal 1
$ inotifywait -m -e open,access,close ~/watch.txt
Setting up watches.
Watches established.

# Terminal 2
$ cat ~/watch.txt
First entry
New entry
New entry
OLD entry
```
What terminal 1 printed:
```
/home/ruin/watch.txt OPEN
/home/ruin/watch.txt ACCESS
/home/ruin/watch.txt CLOSE_NOWRITE,CLOSE
```
Reading is a different signature from writing: **open, access, close-without-write**, with no `MODIFY` anywhere. The `cat` output also confirms the file's final content: `First entry`, `New entry`, `New entry`, `OLD entry`, matching the three appends from Part A.

### ⚙️ Part C — Watching a script
```bash
$ echo '#!/bin/bash
echo "Test script executed"' > ~/test-watch.sh
$ chmod +x ~/test-watch.sh

# Terminal 1
$ inotifywait -m -e open,access,close ~/test-watch.sh
Setting up watches.
Watches established.

# Terminal 2: run the script twice
$ ~/test-watch.sh
Test script executed
$ ~/test-watch.sh
Test script executed
```
What terminal 1 printed:
```
/home/ruin/test-watch.sh OPEN
/home/ruin/test-watch.sh ACCESS
/home/ruin/test-watch.sh CLOSE_NOWRITE,CLOSE
/home/ruin/test-watch.sh OPEN
/home/ruin/test-watch.sh ACCESS
/home/ruin/test-watch.sh CLOSE_NOWRITE,CLOSE
/home/ruin/test-watch.sh OPEN
/home/ruin/test-watch.sh ACCESS
/home/ruin/test-watch.sh CLOSE_NOWRITE,CLOSE
/home/ruin/test-watch.sh OPEN
/home/ruin/test-watch.sh ACCESS
/home/ruin/test-watch.sh CLOSE_NOWRITE,CLOSE
```
I ran the script **twice** but got **four** open-read-close sequences, so the match isn't one event group per run. I haven't checked why. Either way, running a script shows up as plain *reads* of the file, the same signature as `cat`, so with this event list the output can't tell "someone read the script" from "someone ran the script."

### 📝 Part D — Saving the watch to a report file
```bash
# Terminal 1: write everything to a file (stdout and errors), stop with Ctrl-C
$ inotifywait -m -e modify,create,delete ~/watch.txt > ~/file-watch-report.txt 2>&1
^C

# Terminal 2
$ echo "Report test" >> ~/watch.txt

# Terminal 1: read the report
$ cat ~/file-watch-report.txt
Setting up watches.
Watches established.
/home/ruin/watch.txt MODIFY
/home/ruin/watch.txt MODIFY
```
The report holds the two status lines plus two `MODIFY` events (only modify/create/delete were requested, so the open and close events are filtered out). The "Setting up watches" lines are in the file because `2>&1` also redirects the error stream; they are printed there, not on standard output.

---

## 🧪 What I Actually Found

- [x] `inotifywait -m` prints one line per event and keeps running until Ctrl-C
- [x] Appending to a file (`echo ... >>`) = `OPEN`, `MODIFY`, `CLOSE_WRITE,CLOSE`; three appends gave three sequences
- [x] Reading a file (`cat`) = `OPEN`, `ACCESS`, `CLOSE_NOWRITE,CLOSE`, with no `MODIFY`
- [x] Running a script showed up as file reads only: 2 runs produced 4 open-access-close sequences
- [x] `-e` filters the events: with `modify,create,delete` the opens and closes disappeared
- [x] `> file 2>&1` saves the status lines and the events together into one report file
- [x] None of the output says *who* or *which program* touched the file

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: Read or Write?**
> You only see the event names, not the commands. How do you tell whether a file was read or written?

<details>
<summary>My answer</summary>

By the middle event and the close event. A write has `MODIFY` and ends with `CLOSE_WRITE`. A read has `ACCESS` and ends with `CLOSE_NOWRITE`. Both start with `OPEN`, so `OPEN` alone says nothing. My own runs show both patterns: three appends gave `OPEN → MODIFY → CLOSE_WRITE`, and one `cat` gave `OPEN → ACCESS → CLOSE_NOWRITE`.

</details>

> **🥊 Challenge 2: Count the Groups**
> I ran `echo "New entry" >>` twice and `echo "OLD entry" >>` once while watching. How many event groups, and what's in each?

<details>
<summary>My answer</summary>

Three groups, one per command, each made of `OPEN`, `MODIFY` and `CLOSE_WRITE,CLOSE`. That's exactly what the first screenshot shows. Whether the text written was "New entry" or "OLD entry" makes no difference to the events: inotify reports that a write happened, never what was written.

</details>

> **🥊 Challenge 3: Four Groups for Two Runs**
> I ran `test-watch.sh` twice, but the watcher printed four open-access-close groups. What can I conclude, and what can't I?

<details>
<summary>My answer</summary>

I can conclude that running a script is visible to inotify only as reads of the file, and that the number of event groups doesn't map one-to-one onto the number of runs (here 2 runs gave 4 groups). I can't conclude *why* from this output; a guess is that something reads the file more than once per run, but I didn't verify that. The practical lesson is not to count events and treat the number as "how many times it ran."

</details>

> **🥊 Challenge 4: What's Missing?**
> If someone edits an important config file while `inotifywait` is watching, what do I learn, and what do I not learn?

<details>
<summary>My answer</summary>

I learn that the file was opened, modified and closed, and exactly when. I don't learn which user did it, or which program. And if I wasn't running the watcher at that moment, or didn't save its output (Part D), nothing was recorded at all. A tool that records *who* and keeps a persistent log is `auditd`, which is the next step up from this day.

</details>

---

## 🧩 Quick Brain Check

1. What does `-m` do, and what happens to `inotifywait` without it?
2. Which two event names tell you a file was written, and which tell you it was only read?
3. Why was `First entry` (from `echo "First entry" > ~/watch.txt`) missing from the event list?
4. Why does the report file contain "Setting up watches." when only `modify,create,delete` events were requested?
5. What does inotify not tell you about an event?

---

## 🐛 Errors / Gotchas I Hit

- **Event counts don't match commands one-to-one:** two script runs produced four open-access-close groups. Never use the number of events as the number of actions.
- **Running vs reading a script look the same** with `-e open,access,close`: both show as reads.
- **The watcher is blocking:** `inotifywait -m` keeps the terminal busy until Ctrl-C, so each part needs a second terminal.
- **`zsh: corrupt history file /home/ruin/.zsh_history`** appeared when I opened the second terminal. It has nothing to do with inotify; zsh couldn't read its saved command history. Moving the file aside (`mv ~/.zsh_history ~/.zsh_history.bad`) lets zsh start a fresh one.

---

## 🔐 Security Relevance

Watching sensitive files (`/etc/passwd`, SSH configs, the fail2ban config from Day 06) in real time is a simple way to notice tampering the moment it happens, and `inotifywait` can feed a script that sends an alert. Its weakness is also the lesson of the day: an event doesn't say who did it, and it disappears if nobody is watching or saving it. For investigation, you need a tool that records the user and program and keeps a log, which is the gap `auditd` fills.

---

## 🧠 Today's Takeaway

`inotifywait` turns "something touched this file" into a live stream of named events: **a write is OPEN → MODIFY → CLOSE_WRITE, a read is OPEN → ACCESS → CLOSE_NOWRITE**, and the `-e` filter plus a `> file 2>&1` redirect makes it a small logging tool. What it can't do, and what makes it a starting point rather than an audit trail, is say who did it.

---

⬅️ [Back to Sysadmin index](/Sysadmin) | ➡️ Next up: **Day 09: ncdu — finding what's eating your disk**
