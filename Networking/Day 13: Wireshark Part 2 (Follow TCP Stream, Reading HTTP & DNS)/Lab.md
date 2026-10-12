# 🧪 Lab Sheet — Networking Day 13: Wireshark Part 2 (Follow TCP Stream, Reading HTTP & DNS)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

**Only capture traffic on your own machine and your own interfaces.**

**Shortcut:** you can reuse `basic_capture.pcapng` (the loopback capture of 3 curl requests) for Parts A, B and D. Part C needs a fresh capture on `eth0`.

---

## Step 0: Server and Wireshark (skip if you only reuse the saved file)

```bash
# Terminal 1 - local web server, leave it running
cd ~/tcpdump-lab && python3 -m http.server 8080
```
```bash
# Terminal 2
wireshark &
```
To reuse the saved capture: File → Open → `basic_capture.pcapng`.

---

## Part A: Follow a TCP stream

1. Open `basic_capture.pcapng` (or capture 1 to 3 new `curl -s http://127.0.0.1:8080/ > /dev/null` requests on **Loopback: lo**).
2. Right-click the `GET / HTTP/1.1` packet → **Follow → TCP Stream** (shortcut: Ctrl+Alt+Shift+T).
3. In the window that opens, red text is client → server and blue text is server → client. Use the **Show data as** dropdown to switch between ASCII and Hex Dump, and look at the **Entire conversation (... bytes)** label at the bottom.
4. Close the window. Wireshark has put a filter like `tcp.stream eq 0` in the filter bar. Change the number to `1` and `2` to see the other conversations.

📸 Screenshot: `01-follow-tcp-stream.png`

**Note down:**
- How many bytes went client → server and how many server → client? (Use the conversation dropdown to pick each direction.)
- Can you read both the request and the HTML of the page in the stream window?
- Which filter did Wireshark apply, and how many TCP streams are in the file?

---

## Part B: HTTP filters and Export Objects

Clear the filter bar and try each of these, noting **Displayed: X of Y** each time:

```text
B1   http.request.method == "GET"
B2   http.response.code == 200
B3   http.user_agent contains "curl"
B4   http.host == "127.0.0.1:8080"
```

Then pull the page back out of the capture:

1. File → **Export Objects → HTTP...**
2. Select the response in the list and click **Save**, naming it `exported_page.html`.
3. In a terminal:
```bash
ls -l exported_page.html
```

📸 Screenshot: `02-http-filters-and-export.png` (one filter result plus the Export Objects window)

**Note down:**
- The displayed counts for B1 to B4.
- Does the size of `exported_page.html` match the `Content-Length` in the response?
- What does being able to rebuild the page from a capture tell you about plain HTTP?

---

## Part C: DNS traffic on eth0

1. Start a capture on **eth0**.
2. In a terminal:
```bash
dig google.com
dig google.com MX
dig this-name-should-not-exist-12345.com
```
3. Stop the capture and apply these display filters one at a time:
```text
C1   dns
C2   dns.qry.name == "google.com"
C3   dns.flags.rcode == 3
```
4. Click a DNS response and expand **Domain Name System (response)**. Look at the Queries, the Answers, the TTL, and the `[Time: ...]` line.

📸 Screenshot: `03-dns-traffic.png`

**Note down:**
- The IP address(es) and TTL in the `A` answer for `google.com`.
- What did the `MX` answer contain?
- What does the Info column say for the response to the name that doesn't exist, and which filter (C3) found it?
- Does the `[Time: ...]` in Wireshark roughly match dig's `Query time` from Day 02?

---

## Part D: Statistics

Open `basic_capture.pcapng` again, then:

1. **Statistics → Conversations**, then open the **TCP** tab.
2. **Statistics → Protocol Hierarchy**.

📸 Screenshot: `04-statistics.png` (one or both windows)

**Note down:**
- How many TCP conversations are there, and which source ports do they use?
- How many packets and bytes does each conversation have?
- In Protocol Hierarchy, what percentage of packets is HTTP versus plain TCP?

---

## Optional bonus: the same thing from the command line (tshark)

```bash
tshark -r basic_capture.pcapng -Y "http.request"
tshark -r basic_capture.pcapng -q -z conv,tcp
```
`tshark` is Wireshark's command-line version. Note whether its output matches what the GUI showed in Parts B and D.

---

## When you're done

Send me:
1. The screenshots (or a description of what each part showed)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.

**Reminder:** Day 11 (tcpdump filters) is still waiting on its real output. Send it whenever you can so the days are documented in order.
