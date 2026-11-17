# Nextcloud phone app kept logging out, but only at home

**Status:** resolved.

## Summary

The Nextcloud iPhone app kept dropping its login and failing to sign back in, but only on the home network. Away from home it worked. The local reverse proxy was passing Nextcloud the internal upstream address as the host name, so Nextcloud's login flow told the app to finish signing in at an internal IP address the phone could not reach. One header line in the proxy fixed it.

## Impact

- The phone app could not stay signed in at home, so files, calendar and tasks did not sync there.
- Each failed attempt left a stale app login behind on the server.
- No data loss.

## Timeline

- **Before Nov 16:** repeated logouts on the phone, noticed at home.
- **Nov 16:** traced the login flow and found the bad redirect; proxy fixed, config validated and reloaded, login flow re-tested.

## Detection

User report ("the app keeps logging me out"). The useful clue was that it only happened at home.

## Root cause

There are two ways to reach this Nextcloud: from outside through a Cloudflare tunnel, and at home through a local Caddy reverse proxy. Cloudflare passed the public host name through correctly. The local Caddy block did not, so Nextcloud saw the upstream address as the host. Nextcloud's app login flow builds its "finish here" URL from the host it was given, so at home it handed the phone an `https://<internal IP>` address that the app could not complete. The login failed and the app was left signed out.

## Fix

1. Backed up the Caddy config.
2. Added `header_up Host {host}` to the Nextcloud site block, so Caddy forwards the host name the client actually asked for.
3. Validated the config and reloaded Caddy (no restart, no downtime).
4. Re-ran the login flow from the home network: it now returns the public host name, the same one the outside path already used.

## Prevention and follow-ups

- Nextcloud's own proxy settings (which proxies to trust, which scheme and URL to report) are scheduled for review in the next hardening session, so it does not depend on every proxy getting headers exactly right.
- Stale app logins left by the failed attempts get cleaned up with `occ user:auth-tokens:delete` once confirmed safe to drop.

## Lessons

- **"Only at home" is a routing clue, not a device clue.** Two paths to the same service means two configs that can disagree.
- **A reverse proxy has to pass the original host.** Apps that build URLs from the request (login flows, redirects, share links) break quietly when the proxy hands them its own upstream address.
- **Fix the proxy and harden the app.** The header fixes this proxy; trusted proxies and overwrite settings make Nextcloud robust to the next one.
