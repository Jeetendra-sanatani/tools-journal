# 🧪 Lab Sheet — Networking Day 03: curl & wget

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

---

## Step 0: Check the tools are installed
```bash
which curl wget
```
Both are usually pre-installed on Kali. If missing:
```bash
sudo apt update && sudo apt install -y curl wget
```

---

## Part A: curl — headers and status codes

```bash
# A1 - fetch a page, see the body printed to the terminal
curl http://example.com

# A2 - headers ONLY, no body (fast way to check if a site is alive)
curl -I https://example.com

# A3 - verbose mode: see the full request AND response, including TLS handshake
curl -v https://example.com

# A4 - follow redirects (some sites redirect http -> https, or www -> non-www)
curl -L http://github.com

# A5 - save the output to a file instead of printing it
curl -o page.html https://example.com
ls -lh page.html
```
📸 Screenshot: `01-curl-basic-and-headers.png` (A1+A2), `02-curl-verbose.png` (A3), `03-curl-redirect-save.png` (A4+A5)

**Note down:**
- What HTTP status code did A2 show (e.g. 200, 301, 404)?
- In A3, how many steps happen before data starts transferring? (DNS, TCP connect, TLS handshake...)
- Did A4 show any redirect happening, or did it go straight through?

---

## Part B: your own public IP (a genuinely useful one-liner)

```bash
# B1
curl -s https://api.ipify.org
echo ""
```
📸 Screenshot: `04-public-ip.png`

**Note down:**
- Does this IP match what you'd expect (same as what your router/ISP shows)?

---

## Part C: wget — downloading files

```bash
# C1 - simple download
wget https://example.com -O test.html
ls -lh test.html

# C2 - download with progress shown (wget shows this by default, curl needs -# or -o)
wget https://speed.hetzner.de/100MB.bin -O /tmp/speedtest.bin --limit-rate=2m
# (this will take a few seconds - Ctrl+C if you want to stop it early, that's fine)

# C3 - clean up the test files
rm -f test.html page.html /tmp/speedtest.bin
```
📸 Screenshot: `05-wget-download.png`

**Note down:**
- How is wget's default output different from curl's default output?
- Roughly how fast did the download go (check the speed shown during C2)?

---

## When you're done

Send me:
1. The 5 screenshots (or paste the raw terminal text)
2. Your answers to the "note down" questions above
3. Anything that errored, looked weird, or didn't match what you expected

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
