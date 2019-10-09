# Location based configuration management

Detects connected WIFI and uses it for identifying the current location, enabling things like configuration of components that are location bound.


## Background

Consider your NAS was only reachable when being at home. Wouldn't it be great if we could automagically mount the NAS when being at home and only then?


## Setup Automounting

We are mounting in the user home subtree. There are plenty of good reasons to do this instead of old fashioned ways like mounting globally into `/Volumes`.

- copy `homy.sh` to `/usr/local/bin`
- edit `/etc/auto_master`, add (1)
    - replace `<USERNAME>` with your macOS user (e.g. "till")
    - replace `<MOUNTS>` with the name of the folder you want to mount into (e.g. "mnt" but not "Volumes")
    - replace `<DEVICE>` with a remote storage device name (e.g. "stash")
- copy `com.tillt.homy.service.plist` to `/Library/LaunchDaemons`
- edit `/Library/LaunchDaemons/com.tillt.homy.service.plist`
    - see [homy CLI](#homy-cli) for details
- copy `examples/auto_resources.home`, `examples/auto_resources.work` and `examples/auto_resources.unknown` to e.g. `/usr/local/share/homy`
    - edit all of the above to match your demands; (2) shows an example setup
- launch homy as shown in (3)
- check the homy log output (4)

(1) `auto_master` update
```
/Users/<USERNAME>/<MOUNTS>/<DEVICE> auto_resources -noowners,nosuid
```

(2) `auto_resources.home` example
```
Library -fstype=smbfs,soft,noowners,noatime,nosuid smb://till:secret@stash/Library
Downloads -fstype=smbfs,soft,noowners,noatime,nosuid smb://till:secret@stash/downloads
```

(3) launch homy
```bash
sudo launchctl load /Library/LaunchDaemons/com.tillt.homy.service.plist
```

(4) check logging
```bash
tail -f /usr/local/var/log/homy.log
```

## homy CLI

|------|----------|----------------------|
| `-o` | SSID     | home WiFi SSID       |
| `-w` | SSID     | work WiFi SSID       |
| `-t` | PATH     | template location    |
| `-d` | DURATION | poll delay           |
