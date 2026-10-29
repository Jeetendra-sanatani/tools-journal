# 🪟 Sysadmin Day 01: tmux (Terminal Multiplexer)

<p align="center">
  <img src="https://img.shields.io/badge/sysadmin-day_01-blue?style=for-the-badge" alt="Day 01"/>
  <img src="https://img.shields.io/badge/tool-tmux-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> The first day of the Sysadmin phase. The real lesson today wasn't a feature of tmux working smoothly — it was hitting tmux's own safety net, over and over, and figuring out why. 🪟

---

## 🎯 Mission Briefing

The plan was sessions, then windows, then panes, then a disconnect test. What actually happened: every attempt to start or reattach a session from a "fresh" terminal was blocked by tmux itself, because that terminal wasn't actually fresh — it was still inside the session. That single recurring message is today's real finding.

```
🪟 MISSION: Sessions, Windows, Panes, Survive a Disconnect
──────────────────────────────────────────
[x] Create a named session and run commands inside it
[~] Detach and reattach: blocked every time by a nesting warning
[~] Windows: simulated with labeled echo commands, not Ctrl+b c
[~] Panes: simulated with labeled echo commands, not Ctrl+b % / "
[ ] Confirmed survival of a FULLY closed terminal: not demonstrated
──────────────────────────────────────────
STATUS: Sysadmin Day 01 — Needs a redo of Parts B, C and D
```
(`~` = attempted, but what actually happened wasn't what the lab asked for)

---

## ⚡ Quick Theory

**The prefix key.** Every tmux shortcut starts with `Ctrl+b` (press it, release both keys, then press the next key). It's not held together with the second key.

**Three levels, nested inside each other:** a **session** holds one or more **windows**, and a window holds one or more **panes**. `tmux new -s name` makes a session; `Ctrl+b c` makes a new window inside it; `Ctrl+b %` or `"` splits the current window into panes.

**Why "nested" happens.** tmux sets an environment variable, `$TMUX`, inside every shell that's running inside a tmux pane. When you type `tmux new` or `tmux attach` and `$TMUX` is already set, tmux assumes you're trying to start tmux *inside* tmux (nesting it), which almost always isn't what you meant, so it refuses and prints the warning instead of just doing it. The fix for a genuine new attempt is to actually leave the session first (`Ctrl+b d` to detach), not to open another terminal tab that might itself have inherited `$TMUX` from the same parent process. If nesting really is intended, `unset TMUX` before running the command forces it.

**Detaching is a keypress, not closing the window.** `Ctrl+b d` leaves the session running in the background and drops you back to a plain shell. Closing the terminal application entirely is a different, rougher test — tmux should survive that too, but it isn't the same action as detaching.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`, hostname `Devil`. Timestamps across the four screenshots run from 15:03 to 15:15 — about 12 minutes, all consistent with one continuous working session.)*

### 🔁 Sessions — and the first nesting warning
```bash
$ echo "I am inside tmux"
hostname
whoami
I am inside tmux
Devil
ruin

$ tmux ls
lab01: 1 windows (created Wed Oct 14 15:03:04 2026) (attached)

$ tmux attach -t lab01
sessions should be nested with care, unset $TMUX to force
```
`tmux ls` already shows `lab01` as `(attached)` at this point — meaning the session was never actually detached from. Then `tmux attach -t lab01` refused, with tmux's nesting warning. This is the tell: the terminal this was typed into was itself still inside `lab01`, so tmux correctly identified this as an attempt to attach to a session from inside itself, and blocked it.

### 🔂 The same warning, twice more
```bash
$ tmux attach -t lab01
sessions should be nested with care, unset $TMUX to force
```
(appeared at the start of both the "windows" and "panes" screenshots)
```bash
$ tmux new -s survive01
sessions should be nested with care, unset $TMUX to force
```
(appeared at the start of the "disconnect" screenshot)

Four separate attempts across the lab — attaching to `lab01` three times and creating a brand new session `survive01` once — every single one blocked the same way. That consistency is itself informative: this wasn't a one-off mistake, it was the same terminal, still inside `lab01`, for the entire session.

### 🪟 "Windows" — simulated, not actually created
```bash
$ echo "Window 1 - System Information"
hostname
whoami
Window 1 - System Information
Devil
ruin

$ echo "Window 2 - Date and Uptime"
date
uptime
Window 2 - Date and Uptime
Wednesday 14 October 2026 03:07:43 PM IST
15:07:43 up  4:05,  1 user,  load average: 0.34, 0.14, 0.10
```
```bash
$ echo "Pane 1 - System Information"
hostname
whoami
Pane 1 - System Information
Devil
ruin

$ echo "Pane 2 - Date and Uptime"
date
uptime
Pane 2 - Date and Uptime
Wednesday 14 October 2026 03:10:55 PM IST
15:10:55 up  4:09,  1 user,  load average: 0.33, 0.19, 0.12

$ echo "Pane 3 - Memory Usage"
free -h
Pane 3 - Memory Usage
              total        used        free      shared  buff/cache   available
Mem:          7.7Gi       2.2Gi       2.7Gi        23Mi       3.2Gi       5.5Gi
Swap:         5.1Gi          0B       5.1Gi
```
The commands themselves ran fine and gave real, correct output (uptime climbing from `4:05` to `4:09` across the two screenshots, load average shifting slightly, memory stats consistent with an ~8GB machine). But none of this came from actually creating a new window (`Ctrl+b c`) or splitting into panes (`Ctrl+b %` or `"`). It was `echo "Window 1 - ..."` and `echo "Pane 1 - ..."` typed as plain labels, with every command still running one after another in the same single pane. There's no second tmux window shown in a status bar, and no visible split screen — just sequential commands with descriptive names.

### 🧟 The disconnect test — also inside `lab01`, not `survive01`
```bash
$ tmux new -s survive01
sessions should be nested with care, unset $TMUX to force

$ while true; do
  date
  sleep 5
done
Wednesday 14 October 2026 03:12:45 PM IST
Wednesday 14 October 2026 03:12:50 PM IST
... (continuing every 5 seconds through 15:15:40 PM IST)
[lab01] 0:zsh*
```
The status bar at the bottom reads `[lab01] 0:zsh*` — confirming this loop was running inside the original `lab01` session the whole time, not a new `survive01` session (that creation attempt had just failed above). The loop itself worked exactly as expected, ticking every 5 seconds for the full ~3 minutes shown. But the actual test — close the whole terminal application, reopen it, and confirm the loop survived — isn't shown here. What's captured is the loop running continuously inside a session that was never actually left, which doesn't prove tmux kept it alive through a real disconnect.

---

## 🧪 What I Actually Found

- [x] A tmux session (`lab01`) was created and stayed alive across the entire ~12-minute lab
- [x] Commands run inside it gave consistent, correct real output (hostname, whoami, date, uptime, free -h)
- [x] Hit the exact same "nested" warning 4 separate times, trying both `attach` and `new -s`
- [x] `tmux ls` confirmed `lab01` was `(attached)` even at a point meant to be "outside" the session
- [ ] A genuine detach (`Ctrl+b d`) + reattach from a truly separate shell: not demonstrated
- [ ] Real windows (`Ctrl+b c`) and a window list in the status bar: not demonstrated, only simulated with labels
- [ ] Real panes (`Ctrl+b %` / `"`) visible as a split screen: not demonstrated, only simulated with labels
- [ ] Surviving a FULLY closed terminal application: not demonstrated — the long-running loop never left `lab01`

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: Getting Out, For Real**
> Every attempt to attach or create a new session failed with the nesting warning, four times. What's the one action that would have actually gotten to a plain, non-tmux shell, and how would you SEE that you're there (not just assume it)?

<details>
<summary>My answer</summary>

The prefix shortcut `Ctrl+b d` detaches from inside the session, dropping to the shell that launched tmux in the first place. To confirm it worked: run `echo $TMUX` — inside a session it prints a socket path, outside it prints nothing at all. `tmux ls` is also a good check: a freshly detached session shows `(attached)` changing to no `(attached)` tag, since nothing is viewing it anymore.

</details>

> **🥊 Challenge 2: Labels Aren't Panes**
> "Pane 1", "Pane 2" and "Pane 3" were typed as echo text, but no actual pane-splitting command was used. What's the practical difference this makes, beyond just how it looks on screen?

<details>
<summary>My answer</summary>

Real panes run genuinely at the same time, side by side — a `ping` in one pane keeps going while I type in another. Labeled sequential commands in one pane are not simultaneous at all: each one has to finish (or I have to stop watching it) before the next line is typed. The point of panes is parallel visibility; typing labels in sequence gives none of that, only the appearance of organisation in the output.

</details>

> **🥊 Challenge 3: Proving Survival**
> The `while true; do date; sleep 5; done` loop ran for about 3 minutes without stopping. Does that prove it would have survived the terminal application being closed?

<details>
<summary>My answer</summary>

No. It proves the loop kept running while the SAME terminal stayed open and the SAME session stayed attached — that's not a disconnect test at all, it's just a long-running command behaving normally. The actual test requires physically closing the terminal app (not just this pane or window), opening a new one, and running `tmux attach -t <name>` from that fresh terminal to see the loop still going. That step is still outstanding.

</details>

---

## 🧩 Quick Brain Check

1. What does the `$TMUX` environment variable tell tmux, and why does its presence trigger the nesting warning?
2. What's the actual keypress sequence to detach (not close) a session, and what happens to anything running inside it?
3. In your own words: what's the difference between a session, a window and a pane?
4. Why would `tmux ls` showing `(attached)` be a clue that you're still inside the session, even if the terminal looks "normal"?
5. What command instantly tells you whether your current shell is inside a tmux session or not?

---

## 🐛 Errors / Gotchas I Hit

- Every attempt to `tmux attach` or `tmux new -s` from what looked like a fresh terminal was blocked with "sessions should be nested with care, unset $TMUX to force" — meaning the terminal being typed into was never actually outside `lab01` in the first place.
- `tmux ls` showing `lab01` as `(attached)` right before the first blocked attach attempt was the earliest sign of this, worth checking for next time before assuming a detach succeeded.
- "Windows" and "panes" were simulated with `echo "Window 1 - ..."` / `echo "Pane 1 - ..."` labels rather than created with `Ctrl+b c` (new window) or `Ctrl+b %` / `"` (split pane) — the commands' output was real and correct, but the multiplexing itself wasn't demonstrated.
- The disconnect-survival loop ran inside `lab01` (confirmed by the status bar `[lab01] 0:zsh*`), not the intended new session `survive01`, since that session's creation had just failed.

---

## 🔐 Security Relevance

A tmux session surviving a dropped connection is exactly why it matters on a remote server reached over SSH: a long scan, download, or reverse shell handler kept alive in tmux survives a flaky connection, while one running in a plain SSH session dies the moment the connection drops. The flip side matters too — an attacker who gains access to a machine can similarly leave a tmux session running in the background as a form of persistence, and a defender checking `tmux ls` (or `ps aux | grep tmux`, from the Linux journal) on an unfamiliar server is a legitimate way to spot a session nobody remembers starting.

---

## 🧠 Today's Takeaway

The real lesson of Day 01 wasn't "here's how windows and panes look" — it was hitting tmux's own nesting protection four times in a row and working out why: the terminal never actually left the session it started in. That's a genuinely common beginner trap, and understanding `$TMUX` and what a real detach looks like matters more than any single keyboard shortcut. Parts B, C and D need a proper redo: detach for real, confirm with `echo $TMUX`, then try the window and pane splits again.

---

⬅️ [Back to Sysadmin index](/Sysadmin) | ➡️ Next up: **Day 02: lsof — list open files**
