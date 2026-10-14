# 🧪 Lab Sheet — Sysadmin Day 01: tmux (Terminal Multiplexer)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

This opens the Sysadmin phase. The networking series (15 days) is done; this one is about running and managing real systems. tmux is the first tool because every day after this benefits from it: no more juggling GNOME Terminal windows for a listener in one and a client in another.

---

## Step 0: Check it's installed
```bash
which tmux
tmux -V
```
Pre-installed on Kali. If missing: `sudo apt install -y tmux`

---

## Part A: sessions

```bash
# A1 - start a NAMED session (always name it, "it's easier to find later")
tmux new -s lab01

# Inside the session, just to prove it's really a separate shell:
echo "I am inside tmux"
hostname

# A2 - detach WITHOUT closing it: press this key combo (don't type it as text)
#   Ctrl+b   then   d
```
```bash
# A3 - back at your normal shell, list sessions
tmux ls

# A4 - reattach to it
tmux attach -t lab01
# confirm your "echo" from A1 is still there in the scrollback, then detach again (Ctrl+b, d)
```
📸 Screenshot: `01-sessions.png` (A1 inside the session, A3's `tmux ls`, and A4 reattached)

**Note down:**
- What does `tmux ls` show for a session: name, number of windows, size, attached/not?
- After detaching and reattaching, was your shell's state (the `echo` output, your current directory) still there?

---

## Part B: windows (tabs inside one session)

Still inside `lab01` (reattach if you detached):
```text
Ctrl+b  c        create a new window
Ctrl+b  ,        rename the current window
Ctrl+b  n        next window
Ctrl+b  p        previous window
Ctrl+b  0        jump straight to window 0
Ctrl+b  w        list all windows (interactive)
```
Create 3 windows total, rename them `main`, `logs`, `scratch`, and run a different command in each (e.g. `htop` in one, `tail -f /var/log/syslog` in another — Ctrl+C to stop before switching away).

📸 Screenshot: `02-windows.png` (the status bar at the bottom showing all 3 named windows)

**Note down:**
- Where do window names/numbers show up on screen?
- What happens to a running command (like `htop`) when you switch to another window — does it keep running?

---

## Part C: panes (splitting one window)

In the `main` window:
```text
Ctrl+b  %        split pane VERTICALLY (side by side)
Ctrl+b  "        split pane HORIZONTALLY (stacked)
Ctrl+b  arrow key    move between panes
Ctrl+b  z        zoom the current pane to fullscreen (press again to unzoom)
Ctrl+b  x        close the current pane (will ask to confirm)
```
Split into at least 3 panes, run something different in each (e.g. `ping -c 20 127.0.0.1` in one, `watch -n 1 date` in another, a plain shell in the third).

📸 Screenshot: `03-panes.png` (3+ panes visible at once, each doing something different)

**Note down:**
- How is a pane different from a window, in your own words?
- Did zooming (Ctrl+b z) temporarily hide the other panes without closing them?

---

## Part D: the real test — survive a disconnect

```bash
# D1 - inside a pane, start something that keeps running
ping -c 60 127.0.0.1
```
While it's running, **close the entire terminal application** (not just detach — actually close the window/app), then open a fresh terminal and run:
```bash
tmux attach -t lab01
```
📸 Screenshot: `04-survived-disconnect.png` (the ping still running/finished inside tmux, after you reopened the terminal)

**Note down:**
- Was the ping still running (or did it finish on its own) when you reattached?
- What would have happened to that `ping` if it had been running in a plain terminal (no tmux) and you closed the window?

---

## Part E: cleanup

```bash
tmux kill-session -t lab01
tmux ls
```
📸 Screenshot: `05-cleanup.png`

**Note down:**
- What did `tmux ls` print after the session was killed?

---

## When you're done

Send me:
1. The screenshots (or a description of what each part showed)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
