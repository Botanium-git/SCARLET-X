# ScarletX v0.1.0

Minimal WKWebView-based X client intended to run as a LiveContainer guest.

## v0.1.0 goals
- Open `https://x.com/home` in a persistent `WKWebsiteDataStore.defaultDataStore`.
- Preserve normal WebKit cookies/site data between launches when the guest container is preserved.
- Accept incoming URLs through classic UIApplication delegate callbacks and load HTTP/HTTPS URLs into the existing WKWebView.
- Include a `scarletx://?url=...` debug path for direct testing when available.
- Block non-web navigation (for example X's `x-safari-https` app-opening scheme) so it does not bounce out of ScarletX.
- Back/forward/home/reload controls and a tiny status field for first-build diagnostics.

## Build
Push this repository to GitHub. `Build ScarletX IPA` runs on push to `main` or manually from Actions. Download the `ScarletX-v0.1.0` artifact and import the IPA into LiveContainer.

## First test
1. Import and launch ScarletX in LiveContainer.
2. Log into X and verify the login survives a ScarletX relaunch.
3. With LiveContainer's `Always Open URL in Current App` enabled and ScarletX as the current guest, send an X URL through the already-tested `livecontainer://open-web-page?url=<Base64>` path.
4. If LiveContainer forwards the URL through an UIApplication URL callback, ScarletX should navigate to that exact URL and the bottom status briefly shows the callback source.
5. If it only switches to ScarletX and does not navigate, the LiveContainer handoff path differs from the callbacks covered here. Do not rewrite the browser: capture that behavior/log and adjust only the ingress adapter in the next build.

## Important
This first build deliberately does not claim that LiveContainer's HTTPS handoff callback is fully known. The browser core and URL-ingress adapter are separated so the handoff can be corrected without redesigning the app.
