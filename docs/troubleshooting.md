# Troubleshooting

## Check launchd status (macOS)

```bash
launchctl print gui/$UID/com.nix-clawdis.gateway
```

## Check logs

```bash
tail -n 200 ~/.clawdis/logs/clawdis-gateway.log
```

## Common issues

- Missing token file: ensure `botTokenFile` exists and is readable
- No replies: verify `allowFrom` includes your chat ID
- Stuck queue: restart the launchd agent

```bash
launchctl kickstart -k gui/$UID/com.nix-clawdis.gateway
```
