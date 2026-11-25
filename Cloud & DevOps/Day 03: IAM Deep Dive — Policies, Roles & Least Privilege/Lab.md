# 🧪 Lab Sheet — Pentesting Day 03: Burp Suite Part 1 (Intercepting Proxy Basics)

Run these yourself. Take a screenshot at each marked point. Once done, send me the output/screenshots and I'll build the final `README.md` from your real results.

**Reminder:** Day 01 (theHarvester) and Day 02 (Shodan) are still waiting on real output — send those when you can.

---

## ⚠️ Scope for today

**Today's target:** `testphp.vulnweb.com` — Acunetix's own publicly available, intentionally-vulnerable test site, built specifically for people to practice web security tools against. You already found its sibling (`testaspnet.vulnweb.com`) back on Networking Day 03, so this is the same, permitted family of target.

**Never point Burp at any other real website**, even just to "see what happens" — intercepting and modifying traffic to a site you don't own or have permission to test is active interference, not passive recon.

---

## Step 0: Open Burp Suite and configure the browser

1. Open Burp Suite (Community Edition, pre-installed on Kali): **Applications → 03 - Web Application Analysis → burpsuite**, or `burpsuite &` from a terminal.
2. Click through the startup screen: **Temporary project** → **Use Burp defaults** → **Start Burp**.
3. Go to the **Proxy** tab → **Intercept** sub-tab. Note the **Intercept is on/off** button.
4. Configure Firefox (Kali's built-in "Burp Suite Browser" under the Proxy tab is easiest — click **Open Browser** there and skip steps 5-6) OR manually set Firefox's proxy: Settings → Network Settings → Manual proxy → HTTP Proxy `127.0.0.1` port `8080`, check "Also use this proxy for HTTPS".
5. Visit `http://burp` in that browser and install Burp's CA certificate if prompted (needed for HTTPS interception later; today's target is plain HTTP, so this is optional for now but good to set up once).

📸 Screenshot: `01-burp-setup.png` (Burp's Proxy > Intercept tab, visible and configured)

**Note down:**
- What's the difference between Burp's own "Burp Suite Browser" and manually proxying your regular Firefox?

---

## Part A: intercept your first request

```text
1. In Burp, make sure Intercept is ON (the button should say "Intercept is on").
2. In the proxied browser, go to: http://testphp.vulnweb.com/
3. Watch the request arrive in Burp, PAUSED, waiting for you.
```
📸 Screenshot: `02-first-intercept.png`

**Note down:**
- What does the raw intercepted request look like — method, path, headers? Does it look similar to what `curl -v` showed back on Networking Day 03?
- What happens in the browser tab while the request is sitting intercepted in Burp? (It should look "stuck" — why?)

---

## Part B: forward, drop, and the HTTP history

```text
1. With a request intercepted, click "Forward" to let it through.
2. Browse to a couple more pages on the site (e.g. the login page: /login.php).
3. Turn Intercept OFF for a moment, click around the site normally, then turn it back ON.
4. Go to Proxy > HTTP history - this logs EVERY request/response that passed through Burp,
   whether you manually forwarded it or Intercept was off.
```
📸 Screenshot: `03-http-history.png`

**Note down:**
- How many requests show up in HTTP history just from browsing a few pages? Did you expect that many for what felt like "a couple of clicks"?
- Click on one GET and one POST request in the history (visiting `/login.php` and trying to submit the login form will give you both). What's different about what each one carries?

---

## Part C: modify a request before it reaches the server

```text
1. Turn Intercept ON.
2. In the browser, go to the login page (http://testphp.vulnweb.com/login.php) and submit
   the form with any test username/password.
3. Catch that POST request in Burp BEFORE forwarding it.
4. In Burp's intercepted request view, find the username/password fields in the body and
   EDIT them to something different.
5. Click Forward, and see what response comes back.
```
📸 Screenshot: `04-modified-request.png`

**Note down:**
- What did changing the submitted values actually do to the server's response, if anything?
- Why does this matter for security testing — what does being able to edit a request BEFORE it's sent let you test that just using the browser normally never would?

---

## Part D: Repeater — resending and tweaking a request

```text
1. In HTTP history, right-click any interesting request (the login POST is a good one) and
   choose "Send to Repeater".
2. In the Repeater tab, you'll see the same request, editable, with a "Send" button.
3. Change something in it (a parameter value, a header) and click Send - see the response
   on the right, without needing to go back to the browser at all.
4. Try sending it 2-3 times with different values, comparing the responses.
```
📸 Screenshot: `05-repeater.png`

**Note down:**
- What's the practical advantage of Repeater over doing this in the intercepted-request view each time?
- Did any of your edited values produce a noticeably DIFFERENT response (different length, different status code, different content)? That's often the first sign worth investigating further.

---

## When you're done

Send me:
1. The screenshots (or a description of what each part showed)
2. Your answers to the "note down" questions above
3. Anything that errored or looked weird

I'll turn this into the final `README.md`, fill in `commands.txt`, and help you write `notes.txt`.
