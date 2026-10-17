# 🧪 Lab Sheet — Sysadmin Day 04: iptables Part 1 (Tables, Chains & Basic Rules)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

**Reminder:** Day 03 (strace) is still waiting on real output. Send that when you can.

---

## ⚠️ Read this before touching anything

`iptables` is the real firewall engine underneath `ufw` (the tool used on Linux journal Day 21 — `ufw` is just a friendlier frontend that writes `iptables` rules for you). Direct `iptables` rules are more powerful and easier to lock yourself out with.

**Rules for today:**
- Do this only on your own Kali VM, where you have **console access** (the VM window itself), not only a remote SSH session. If you somehow block yourself out over SSH, console access is how you recover.
- Before adding anything that blocks traffic, know how to undo it: `iptables -F` flushes (deletes) all rules in a table back to empty.
- Default policies stay `ACCEPT` all day today — nothing here should actually leave your VM unreachable. Day 05's firewall script is where policies tighten up, and it gets its own extra warning.

---

## Step 0: Check it's installed, see the starting state
```bash
which iptables
sudo iptables -L -v -n
sudo iptables -S
```
Pre-installed on Kali. `-L -v -n` lists rules in a readable table; `-S` lists them as the exact commands that would recreate them.

---

## Part A: tables and chains — just looking

```bash
# A1 - the filter table (default, used for basic ACCEPT/DROP decisions) - 3 built-in chains
sudo iptables -t filter -L -v -n

# A2 - the nat table - a completely separate rule set, for address translation (Day 05 topic)
sudo iptables -t nat -L -v -n

# A3 - packet/byte counters reset to zero, then watch them grow
sudo iptables -Z
ping -c 3 127.0.0.1
sudo iptables -L INPUT -v -n
```
📸 Screenshot: `01-tables-and-chains.png`

**Note down:**
- Name the 3 built-in chains in the `filter` table, and in one line each, what traffic each one sees (INPUT = traffic TO this machine, etc.)
- After the 3 pings in A3, did the INPUT chain's packet counter go up by 3, by 6, or something else? (Think about what a ping to yourself actually does — Linux journal Day 1.)

---

## Part B: your first rules — ACCEPT and DROP

```bash
# B1 - explicitly ACCEPT loopback traffic (usually already allowed by default, but make it explicit)
sudo iptables -A INPUT -i lo -j ACCEPT

# B2 - DROP all ICMP (ping) coming IN to this machine
sudo iptables -A INPUT -p icmp -j DROP

# B3 - test it: ping yourself from the OUTSIDE perspective won't work here (loopback bypasses INPUT
#      the way you'd expect from another host), so test by pinging your eth0 IP from this same machine
ip -4 addr show eth0 | grep inet
ping -c 3 <your-eth0-ip>

# B4 - see the rule that caused it
sudo iptables -L INPUT -v -n --line-numbers
```
📸 Screenshot: `02-accept-and-drop.png`

**Note down:**
- What did the ping in B3 do — timeout, or an immediate "Destination unreachable"? (DROP vs REJECT behave differently — something to explore later.)
- In B4's output, which rule's packet counter increased after the ping?

---

## Part C: rule order matters (first match wins)

```bash
# C1 - add an ACCEPT rule for ICMP ABOVE the DROP you just made, using -I (insert) not -A (append)
sudo iptables -I INPUT 1 -p icmp -s 127.0.0.1 -j ACCEPT

# C2 - list with line numbers to see the new order
sudo iptables -L INPUT -v -n --line-numbers

# C3 - test: does ping to your own eth0 IP from localhost work now?
ping -c 3 <your-eth0-ip>
```
📸 Screenshot: `03-rule-order.png`

**Note down:**
- What's the actual order of rules now (1, 2, 3...)? Does the new ACCEPT sit above or below the DROP?
- Does C3's ping succeed now? Explain WHY based on rule order, not just "because I added an ACCEPT."

---

## Part D: clean up safely

```bash
# D1 - remove just the ICMP rules you added (by line number, from Part C's output - delete from
#      the BOTTOM number up, so earlier numbers don't shift under you)
sudo iptables -D INPUT <line-number>
sudo iptables -D INPUT <line-number>

# D2 - or, the blunt but reliable option: flush everything back to empty
sudo iptables -F

# D3 - confirm you're back to a clean slate
sudo iptables -L -v -n
ping -c 3 127.0.0.1
```
📸 Screenshot: `04-cleanup.png`

**Note down:**
- After `-F`, did pinging loopback work normally again?
- Why delete rules from the bottom line number up, rather than top-down, when removing more than one by number?

---

## When you're done

Send me:
1. The screenshots (or a description of what each part showed)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
