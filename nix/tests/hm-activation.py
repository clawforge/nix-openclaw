start_all()

machine.wait_until_succeeds(
    "systemctl show -p Result home-manager-alice.service | grep -q 'Result=success'"
)

machine.wait_until_succeeds("test -f /home/alice/.openclaw/openclaw.json")

uid = machine.succeed("id -u alice").strip()
machine.succeed("loginctl enable-linger alice")
machine.succeed(f"systemctl start user@{uid}.service")
machine.wait_for_unit(f"user@{uid}.service")

machine.wait_until_succeeds("test -S /run/user/1000/bus")

user_env = "XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
machine.succeed(f"su - alice -c '{user_env} systemctl --user daemon-reload'")
machine.succeed(f"su - alice -c '{user_env} systemctl --user start openclaw-gateway.service'")
machine.wait_for_unit("openclaw-gateway.service", user="alice")

try:
    machine.wait_for_open_port(18999)
except Exception:
    machine.succeed(
        f"su - alice -c '{user_env} systemctl --user status openclaw-gateway.service --no-pager -n 200 2>&1' || true"
    )
    machine.succeed(
        f"su - alice -c '{user_env} systemctl --user show openclaw-gateway.service -p ActiveState -p SubState -p ExecMainCode -p ExecMainStatus -p MainPID --no-pager 2>&1' || true"
    )
    machine.succeed(
        f"su - alice -c '{user_env} systemctl --user cat openclaw-gateway.service --no-pager 2>&1' || true"
    )
    machine.succeed(
        "journalctl --user -u openclaw-gateway.service --no-pager -n 200 2>&1 || true"
    )
    machine.succeed("ls -la /tmp/openclaw/openclaw-gateway.log || true")
    machine.succeed("tail -n 200 /tmp/openclaw/openclaw-gateway.log || true")
    machine.succeed("tail -n 200 /tmp/openclaw/openclaw.log || true")
    machine.succeed("ls -la /tmp/openclaw || true")
    machine.succeed("ps -eo pid,ppid,cmd | grep -E '[o]penclaw|[n]ode' || true")
    machine.succeed("ls -la /tmp/openclaw/node-report* || true")
    machine.succeed("tail -n 200 /tmp/openclaw/node-report* || true")
    machine.succeed("coredumpctl info --no-pager | tail -n 200 || true")
    raise
