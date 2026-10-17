# 🧱 Sysadmin Day 04: iptables Part 1 (Tables, Chains & Basic Rules)

<p align="center">
  <img src="https://img.shields.io/badge/sysadmin-day_04-blue?style=for-the-badge" alt="Day 04"/>
  <img src="https://img.shields.io/badge/tool-iptables-orange?style=for-the-badge" alt="Tool"/>
  <img src="https://img.shields.io/badge/level-beginner-yellow?style=for-the-badge" alt="Level"/>
  <img src="https://img.shields.io/badge/lab-Kali_Linux-black?style=for-the-badge" alt="Lab"/>
</p>

> Turns out this machine already runs `ufw` AND Docker, both of which build their own iptables chains on top of the plain ones — so today became a lesson in what real iptables output actually looks like, not the simplified textbook version. 🧱

---

## 🏆 Day 03 Recap — The Filter Blind Spot

A trace filtered to `openat` alone never showed `ls`'s missing-directory check, because `ls` checks with a different syscall entirely (likely `statx`). The lesson carries forward: if a tool's output doesn't show what you expected, check whether you filtered out the part that mattered, before assuming nothing happened.

---

## 🎯 Mission Briefing

The plan was to see 3 clean built-in chains, add a couple of rules, and watch order matter. What showed up instead was the real state of an actual working machine: `ufw`'s own chain system already owns `INPUT`, and Docker has inserted a whole family of chains into `FORWARD` and the `nat` table for its own container networking. That turned out to be a better lesson than the clean version would have been.

```
🧱 MISSION: Tables, Chains & Basic Rules
──────────────────────────────────────────
[x] View the filter table and find it's NOT just 3 simple chains
[x] View the nat table and find real Docker NAT rules already there
[x] Insert and delete rules, and see exactly where -I places them
[x] Discover that -D removes only ONE matching rule at a time
[~] Prove DROP/ACCEPT actually changed real traffic: rules were correct, a live connection test wasn't captured
──────────────────────────────────────────
STATUS: Sysadmin Day 04 — Done, with one gap in Part B
```

---

## ⚡ Quick Theory (corrected against what actually showed up)

**The "3 built-in chains" story is the starting point, not the whole picture.** `INPUT`, `OUTPUT` and `FORWARD` are what the kernel provides, but any tool that manages a firewall — `ufw`, Docker, and others — adds its OWN chains and inserts a jump to them at the top of the built-in ones. What you see in `iptables -L` is the combination of everything currently managing the system, not just your own rules.

**`-I INPUT 1` always means "right at the very top", every time.** If two separate `-I INPUT 1` commands run (even from two different terminals), the SECOND one to execute ends up at position 1, and the first one gets pushed down to position 2. Position 1 isn't "my rule's permanent spot" — it's "whatever got inserted there most recently."

**`-D` by rule-spec removes exactly ONE match, not every copy.** If the same rule got added multiple times (easy to do by accident, or on purpose while testing), one `-D <same-spec>` call only removes the first one iptables finds. Running it again removes the next, and so on — it doesn't deduplicate everything in one shot.

**`-C` (check) is the clean way to confirm a rule is truly gone**, without needing to scroll through a long `-L` listing: it returns a normal success/fail exit code, which scripts can act on directly.

---

## 💻 Lab: Commands + My Real Output

*(Machine: Kali Linux, user `ruin`, working in `/usr/share/wordlists`. `ufw` and Docker are both active on this machine.)*

### 🗺️ The filter table — not 3 simple chains
```bash
$ sudo iptables -L -n -v
Chain INPUT (policy DROP 740 packets, 43886 bytes)
 1232  451K ufw-before-logging-input  all  --  *  *  0.0.0.0/0  0.0.0.0/0
 1232  451K ufw-before-input          all  --  *  *  0.0.0.0/0  0.0.0.0/0
 1042 84490 ufw-after-input            all  --  *  *  0.0.0.0/0  0.0.0.0/0
  740 43886 ufw-after-logging-input     all  --  *  *  0.0.0.0/0  0.0.0.0/0
  740 43886 ufw-reject-input             all  --  *  *  0.0.0.0/0  0.0.0.0/0
  740 43886 ufw-track-input               all  --  *  *  0.0.0.0/0  0.0.0.0/0

Chain FORWARD (policy DROP 0 packets, 0 bytes)
  199  152K DOCKER-USER       all  --  *  *  0.0.0.0/0  0.0.0.0/0
  199  152K DOCKER-FORWARD     all  --  *  *  0.0.0.0/0  0.0.0.0/0
    0     0 ufw-before-logging-forward  all  --  *  *  0.0.0.0/0  0.0.0.0/0
    0     0 ufw-before-forward            all  --  *  *  0.0.0.0/0  0.0.0.0/0
    0     0 ufw-after-forward              all  --  *  *  0.0.0.0/0  0.0.0.0/0
    0     0 ufw-reject-forward               all  --  *  *  0.0.0.0/0  0.0.0.0/0
    0     0 ufw-track-forward                 all  --  *  *  0.0.0.0/0  0.0.0.0/0

Chain OUTPUT (policy ACCEPT 14 packets, 560 bytes)
  226 20599 ufw-before-logging-output  all  --  *  *  0.0.0.0/0  0.0.0.0/0
  ... (ufw-before-output, ufw-after-output, ufw-after-logging-output, ufw-reject-output, ufw-track-output)

Chain DOCKER (2 references)
Chain DOCKER-BRIDGE (1 references)
Chain DOCKER-CT (1 references)
  113 65753 ACCEPT  all  --  br-81243d49950f  0.0.0.0/0  0.0.0.0/0  ctstate RELATED,ESTABLISHED
Chain DOCKER-FORWARD (1 references)
Chain DOCKER-ISOLATION-STAGE-1 (1 references)
Chain DOCKER-ISOLATION-STAGE-2 (2 references)
Chain DOCKER-USER (1 references)
```
Three things worth pulling out of this:

- **`INPUT`'s default policy is already `DROP`**, not the `ACCEPT` the lab sheet assumed as a starting point — because `ufw` sets that itself when it's enabled (the same thing seen on Linux journal Day 21).
- **Every rule in `INPUT`, `FORWARD` and `OUTPUT` is a jump to a `ufw-*` chain**, not a direct ACCEPT/DROP decision. `ufw`'s real rules live INSIDE those chains, not in the built-in ones directly — this is exactly how `ufw` manages to be a "friendly frontend": it owns and organizes its own set of chains underneath.
- **Docker added 6 extra chains on top of that** (`DOCKER`, `DOCKER-USER`, `DOCKER-FORWARD`, `DOCKER-BRIDGE`, `DOCKER-CT`, `DOCKER-ISOLATION-STAGE-1/2`), all feeding into `FORWARD`, because Docker needs to decide which container-to-container and container-to-outside traffic is allowed. `DOCKER-CT`'s one active rule (`ctstate RELATED,ESTABLISHED`) is the exact same "allow replies to connections already started" pattern the Day 05 base firewall script uses — Docker is already doing it.

### 🌐 The nat table — real Docker port-forwarding, live
```bash
$ sudo iptables -t nat -L -n -v
Chain PREROUTING (policy ACCEPT 1038 packets, 82582 bytes)
    5  5088 DOCKER  all -- * *  0.0.0.0/0  0.0.0.0/0  ADDRTYPE match dst-type LOCAL

Chain POSTROUTING (policy ACCEPT 90 packets, 10290 bytes)
    0     0 MASQUERADE  all -- * !docker0           172.17.0.0/16  0.0.0.0/0
    5   300 MASQUERADE  all -- * !br-81243d49950f   172.18.0.0/16  0.0.0.0/0

Chain DOCKER (2 references)
    0 0 RETURN  all -- docker0 *             0.0.0.0/0  0.0.0.0/0
    0 0 RETURN  all -- br-81243d49950f *      0.0.0.0/0  0.0.0.0/0
    0 0 DNAT    tcp -- !br-81243d49950f *       0.0.0.0/0  127.0.0.1  tcp dpt:4222 to:172.18.0.2:4222
    0 0 DNAT    tcp -- !br-81243d49950f *        0.0.0.0/0  0.0.0.0/0  tcp dpt:3000 to:172.18.0.3:3000
    0 0 DNAT    tcp -- !br-81243d49950f *         0.0.0.0/0  0.0.0.0/0  tcp dpt:9458 to:172.18.0.3:9458
    0 0 DNAT    tcp -- !br-81243d49950f *          0.0.0.0/0  127.0.0.1  tcp dpt:27017 to:172.18.0.4:27017

$ sudo iptables -t mangle -L -n -v
Chain PREROUTING (policy ACCEPT 0 packets, 0 bytes)
... (all 5 chains present, every counter at 0 - the table exists but nothing uses it here)
```
This is the Day 05 topic (NAT) showing up a day early, already running: two `MASQUERADE` rules in `POSTROUTING`, one per Docker network (`172.17.0.0/16` for the default `docker0` bridge, `172.18.0.0/16` for a custom one, `br-81243d49950f`) — this is what lets containers reach the outside internet while appearing to come from this machine's own address. And four `DNAT` rules in the `DOCKER` chain, each one mapping a port on this machine straight to a specific container's IP and port (`4222 → 172.18.0.2:4222`, `3000 → 172.18.0.3:3000`, and so on) — this is literally what `docker run -p <port>:<port>` does under the hood, implemented as ordinary NAT rules. `mangle`, by contrast, exists as a table but has zero traffic through any of its chains on this machine — present, unused.

### 🔀 Insert position and rule order (two terminals, same test)
```bash
# Terminal 1 (left)
$ sudo iptables -I INPUT 1 -i lo -p tcp --dport 8088 -j DROP

# Terminal 2 (right, running at the same time)
$ sudo iptables -I INPUT 1 -i lo -p tcp --dport 8088 -j ACCEPT
```
```bash
$ sudo iptables -L INPUT -n -v --line-numbers
num pkts bytes target  ...
1      0    0 DROP    tcp -- lo * ... tcp dpt:8088
2      0    0 ACCEPT  tcp -- lo * ... tcp dpt:8088
3      0    0 DROP    tcp -- lo * ... tcp dpt:8088
4      0    0 ACCEPT  tcp -- lo * ... tcp dpt:8088
5   1298  456K ufw-before-logging-input ...
```
Two `-I INPUT 1` commands, one from each terminal, produced 4 stacked rules at the top (DROP, ACCEPT, DROP, ACCEPT) — confirming `-I ... 1` genuinely means "whatever's inserted lands at position 1 right now", pushing everything that was already there down by one, every single time it runs.

```bash
$ sudo iptables -D INPUT -i lo -p tcp --dport 8088 -j DROP
$ sudo iptables -L INPUT -n -v --line-numbers
1   0 0 ACCEPT  tcp -- lo * ... tcp dpt:8088
2   0 0 DROP    tcp -- lo * ... tcp dpt:8088
3   0 0 ACCEPT  tcp -- lo * ... tcp dpt:8088
4 1298  456K ufw-before-logging-input ...

$ sudo iptables -D INPUT -i lo -p tcp --dport 8088 -j DROP
$ sudo iptables -L INPUT -n -v --line-numbers
1   0 0 ACCEPT  tcp -- lo * ... tcp dpt:8088
2 1112 89664 ufw-before-logging-input ...
```
Each `-D` by the same rule-spec removed exactly ONE of the two DROP rules, not both at once — the first call dropped the count from 4 rules to 3 (one DROP gone, one DROP + 2 ACCEPTs left), and a second, identical `-D` call was needed to remove the other DROP. Deleting by spec is first-match-only, every time.

### ❌ A delete that failed — and why
```bash
$ sudo iptables -D INPUT -i lo -p tcp --dport 8088 -j ACCEPT
iptables: Bad rule (does a matching rule exist in that chain?).
```
One delete attempt by spec came back with "Bad rule" — iptables requires the delete command's match spec to line up EXACTLY with how the rule was actually stored, and something in this attempt (likely a subtle difference the basic flags shown don't fully capture) didn't match closely enough for `-D` to find it. The eventual full cleanup (below) got there by retrying with `2>/dev/null` guards rather than needing to diagnose the exact mismatch.

### 🧹 Thorough, idempotent cleanup
```bash
$ sudo iptables -D INPUT -i lo -p tcp --dport 8088 -j DROP 2>/dev/null
$ sudo iptables -D INPUT -i lo -p tcp --dport 8088 -j ACCEPT 2>/dev/null

$ sudo iptables -S INPUT
-P INPUT DROP
-A INPUT -j ufw-before-logging-input
-A INPUT -j ufw-before-input
-A INPUT -j ufw-after-input
-A INPUT -j ufw-after-logging-input
-A INPUT -j ufw-reject-input
-A INPUT -j ufw-track-input
```
```bash
$ sudo iptables -C INPUT -i lo -p tcp --dport 8088 -j DROP
echo "DROP rule check exit code: $?"
iptables: Bad rule (does a matching rule exist in that chain?).
DROP rule check exit code: 1

$ sudo iptables -C INPUT -i lo -p tcp --dport 8088 -j ACCEPT
echo "ACCEPT rule check exit code: $?"
iptables: Bad rule (does a matching rule exist in that chain?).
ACCEPT rule check exit code: 1
```
`-S INPUT` confirms the chain is back to exactly what it was before today's test — just the original `ufw` jump rules, nothing extra. Using `-C` (check) afterward to confirm BOTH test rules are gone, by exit code rather than by eye, is a solid verification habit: exit code `1` means "no matching rule found," which is exactly the clean state being confirmed. The `2>/dev/null` on the delete commands is a nice touch too — it makes the cleanup safe to run even if a rule had already been removed, without an error stopping the script.

---

## 🧪 What I Actually Found

- [x] `INPUT`'s real default policy on this machine is `DROP` (via `ufw`), not `ACCEPT`
- [x] Every `INPUT`/`FORWARD`/`OUTPUT` rule here is a jump to a `ufw-*` or `DOCKER*` chain, not a direct decision — real rules live one level deeper
- [x] The `nat` table already has live Docker `MASQUERADE` and `DNAT` rules, a working preview of Day 05's topic
- [x] `mangle` exists but carries zero traffic on this machine
- [x] `-I INPUT 1` always inserts at the very top, confirmed by two terminals racing to position 1
- [x] `-D <spec>` removes exactly one matching rule per call, demonstrated by needing two identical `-D` calls to clear two identical DROP rules
- [x] One `-D` attempt failed with "Bad rule", and full cleanup was reached with `2>/dev/null` plus a `-C`-based verification instead
- [ ] A live connection test (e.g. `curl` to port 8088) proving DROP actually blocked traffic and ACCEPT actually allowed it: not captured — only the rule table itself was checked

---

## 🎯 Mini Challenges

> **🥊 Challenge 1: Whose Rule Wins?**
> Two terminals each ran `iptables -I INPUT 1 ...` — one with `-j DROP`, one with `-j ACCEPT` — at roughly the same time, and the final order was DROP, ACCEPT, DROP, ACCEPT. What determined that specific order, and could it have come out differently?

<details>
<summary>My answer</summary>

Whichever `-I INPUT 1` command the kernel actually executed LAST ends up at position 1, and that pushes everything already there down by one. The order (DROP, ACCEPT, DROP, ACCEPT) reflects the actual execution order across the two terminals: DROP first (landing at 1), then ACCEPT (landing at 1, pushing DROP to 2), then evidently a second round of the same two commands repeated the pattern. If the terminals had been triggered in a different order, or with different timing, the final stack could easily have come out as ACCEPT, DROP, ACCEPT, DROP instead — `-I ... 1` has no memory of "whose turn it is," it's purely about execution order.

</details>

> **🥊 Challenge 2: One Down, One to Go**
> After the first `iptables -D INPUT -i lo -p tcp --dport 8088 -j DROP`, there was still one DROP rule left in the chain, and a second identical `-D` call was needed to clear it. Why doesn't `-D` just remove every rule that matches the spec in one go?

<details>
<summary>My answer</summary>

`-D` by rule-spec is designed to remove exactly one occurrence per call — the same behavior as deleting "the first line that looks like this" rather than "every line that looks like this." This matters because rules with identical specs can still be meaningfully different in the order they're checked (first-match-wins), so iptables doesn't assume duplicates are interchangeable and safe to bulk-remove; it removes one, and leaves the rest for a deliberate follow-up call.

</details>

> **🥊 Challenge 3: Rules Correct, But Proven?**
> The INPUT chain clearly had the right DROP and ACCEPT rules in the right positions at each step. Does that alone prove traffic to port 8088 was actually being blocked or allowed as expected?

<details>
<summary>My answer</summary>

Not fully. Reading the rule table shows what SHOULD happen according to the configuration, but it's not the same as confirming what actually DID happen to real traffic. The honest next step is a live test — starting the server on 8088, then trying to connect to it (with `curl` or similar) while each rule is active, and checking whether the connection succeeds or fails as expected. That test wasn't captured this round, so the rule logic is confirmed, but its real-world effect on a connection attempt isn't yet.

</details>

---

## 🧩 Quick Brain Check

1. Why did `INPUT`'s policy show as `DROP` here instead of the `ACCEPT` default the lab sheet assumed?
2. What's the practical difference between a rule that's a direct `ACCEPT`/`DROP` decision and one that's a jump to another chain (like `ufw-before-input`)?
3. If `iptables -I INPUT 1` is run three times in a row with three different rules, what's the final order of those three rules?
4. Why did deleting the SAME rule spec twice remove two different DROP rules, one at a time, instead of nothing happening the second time?
5. What does an `-C` (check) exit code of `1` actually confirm, compared to just reading through `-L` output?

---

## 🐛 Errors / Gotchas I Hit

- One `sudo` prompt needed a second attempt ("Sorry, try again") — a simple mistyped password, not an iptables issue.
- A separate terminal showed `zsh: corrupt history file /home/ruin/.zsh_history` — a zsh housekeeping warning, unrelated to anything iptables was doing.
- `iptables -D INPUT -i lo -p tcp --dport 8088 -j ACCEPT` failed once with "Bad rule (does a matching rule exist in that chain?)" — the rule-spec given to `-D` has to match exactly how the rule is actually stored, and something about this attempt didn't line up precisely enough, even though the rule was genuinely present.
- The lab sheet's assumption of "3 clean built-in chains" didn't hold on this machine at all — `ufw` and Docker both add their own chains, and that turned out to be more informative than the idealized version would have been.

---

## 🔐 Security Relevance

Seeing `ufw`'s real structure underneath its friendly command-line tool is exactly why direct `iptables` knowledge matters even when `ufw` is "handling" the firewall — the actual decisions happen in `ufw-before-input`/`ufw-after-input`/`ufw-reject-input`, and auditing a system properly means looking there, not just trusting that `ufw status` tells the whole story. Docker's automatic `DNAT`/`MASQUERADE` rules are also a common surprise during a security review: a port can be reachable from outside specifically because a container published it, even if nothing in `ufw`'s own rule list mentions that port at all — the two systems manage different layers of the same `iptables` ruleset.

---

## 🧠 Today's Takeaway

The textbook version of iptables ("3 chains, add a rule, done") is the right starting mental model, but a real machine running `ufw` and Docker looks nothing like that — both tools build their own chain structures underneath the simple picture, and the `nat` table can already be doing real work (port-forwarding into containers) before a single manual rule is added. `-I` always claims position 1 on execution, and `-D` only ever removes one match at a time — both worth remembering before assuming a single command "cleaned everything up."

---

⬅️ [Back to Sysadmin index](../README.md) | ➡️ Next up: **Day 05: iptables Part 2 — logging, NAT, saving rules**
