# 🧪 Lab Sheet — Networking Day 02: dig, nslookup & whois

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

---

## Step 0: Check the tools are installed
```bash
which dig nslookup whois
```
If `dig`/`nslookup` are missing:
```bash
sudo apt update && sudo apt install -y dnsutils
```
If `whois` is missing:
```bash
sudo apt install -y whois
```

---

## Part A: dig — the detailed DNS lookup tool

```bash
# A1 - basic lookup (A record = the IP address)
dig google.com

# A2 - short output, just the answer
dig google.com +short

# A3 - a different record type: MX (mail servers)
dig google.com MX +short

# A4 - NS records (which nameservers are authoritative for this domain)
dig google.com NS +short

# A5 - ask a SPECIFIC DNS server directly (not your default one)
dig @8.8.8.8 google.com +short

# A6 - reverse lookup: given an IP, find the hostname
dig -x 8.8.8.8 +short
```
📸 Screenshot: `01-dig-basic.png` (A1), `02-dig-short-records.png` (A2+A3+A4), `03-dig-specific-server-reverse.png` (A5+A6)

**Note down:**
- What IP did `google.com` resolve to in A1/A2?
- How many MX records came back in A3? (There are usually several, with priority numbers)
- Did A5 give the same IP as A2? (It should, usually)

---

## Part B: nslookup — the simpler, older lookup tool

```bash
# B1 - basic lookup
nslookup google.com

# B2 - query a specific record type
nslookup -type=MX google.com

# B3 - use a specific DNS server
nslookup google.com 8.8.8.8
```
📸 Screenshot: `04-nslookup.png`

**Note down:**
- Compare B1's output style to dig's A1 output — which do you find easier to read?

---

## Part C: whois — who owns this domain?

```bash
# C1 - basic whois lookup
whois google.com

# C2 - whois on your own IP or a public one (ownership of an IP block)
whois 8.8.8.8
```
📸 Screenshot: `05-whois.png`

**Note down:**
- Who is the registrar for google.com?
- What creation date does the domain show?
- For `whois 8.8.8.8` — which organization owns that IP block?

---

## When you're done

Send me:
1. The 5 screenshots (or paste the raw terminal text)
2. Your answers to the "note down" questions above
3. Anything that errored, looked weird, or didn't match what you expected

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
