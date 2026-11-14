# Monitoring and centralized logging

Monitoring for a two-node Proxmox lab and the services on it. The goal is to know quickly when something breaks without getting a message every five minutes.

## Pieces

- **Uptime Kuma** checks each service's real endpoint (for example the HTTPS port a service actually serves), not just a ping.
- **Proxmox watchdog in n8n:** every 5 minutes it checks the cluster API and key services, and alerts on a change only: when something goes down or comes back. No change, no message.
- **Central syslog:** an rsyslog receiver writes one file per sending device and rotates weekly. I set it up to catch a network switch that kept rebooting and losing its in-memory log on every reboot.
- **Global error workflow:** every n8n workflow points to one error handler. It deduplicates by incident, so one outage gives one alert, not hundreds.
- **Mail watchdog:** catches mail that arrived but was never processed (see the email triage project).

## Lessons

- Monitor the port a service really serves on. One of my checks pointed at a port that a firewall rule had closed to everything but two hosts, so it was moved to the service's real HTTPS port.
- A scheduled job with no time budget will eventually meet a batch slow enough to kill it, and then it retries the same batch forever.
- If an alert fires every hour, people stop reading alerts. Fix the cause or fix the alert.

## Stack

Proxmox VE, Uptime Kuma, rsyslog, logrotate, n8n, Discord webhooks.
