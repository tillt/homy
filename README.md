# Location based configuration management (for Music.app)

Detects connected WIFI and uses it for identifying the current location, enabling things like configuration of components that are location bound.


## Background

Consider your NAS was only reachable when being at home. Wouldn't it be great if we could automagically mount the NAS when being at home and only then?
Autofs itself does most of the heavy lifting, but some macOS services may feel really sick when they fail to reach the NAS - namely iTunes / Music is
well known to totally not get along with removable shares for its media storage location.

This tool was born while trying to get Music.app to support my NAS when at home.

The rest of this documentation is describing that specific usecase while homy itself is flexible enough to do much more.


## Setup Automounting

NOTE: We are **not** mounting in the user home subtree as that causes bizarre issues on macOS Catalina; see
We are mounting globally, in the system volume data subtree.

- copy `homy.sh` to `/usr/local/bin`
- edit `/etc/auto_master`, add (1)
    - replace `<USERNAME>` with your macOS user (e.g. "till")
    - replace `<MOUNTS>` with the name of the folder you want to mount into (e.g. "mnt" but not "Volumes")
    - replace `<DEVICE>` with a remote storage device name (e.g. "stash")

(1) `auto_master` update
```
/System/Volumes/Data/<MOUNTS>/<DEVICE> auto_resources -noowners,nosuid
```


### Optional Path Mapping

Additionally, we can map that subtree up into the root folder by using `synthetic.conf`.
- create or edit `/etc/synthetic.conf`, add (2)

(2) `synthetic.conf` update
```
<DEVICE> /System/Volumes/Data/<MOUNTS>/<DEVICE>
```


## Setup Music.app

- run Music.app using option-start
- make sure you have the media library selected that points to your NAS shares
- quit Music.app

- copy `~/Library/Preferences/com.apple.Music.plist` to `/usr/local/share/homy/com.apple.Music.plist.home`
- copy `~/Library/Preferences/com.apple.Music.plist` to `/usr/local/share/homy/com.apple.Music.plist.unknown`
- copy `~/Library/Preferences/com.apple.AMPLibraryAgent.plist` to `/usr/local/share/homy/com.apple.AMPLibraryAgent.plist.home`
- copy `~/Library/Preferences/com.apple.AMPLibraryAgent.plist` to `/usr/local/share/homy/com.apple.AMPLibraryAgent.plist.unknown`

- run Music.app using option-start
- make sure you have a (new) media library selected that points to your local storage
- quit Music.app

- copy `~/Library/Preferences/com.apple.Music.plist` to `/usr/local/share/homy/com.apple.Music.plist.work`
- copy `~/Library/Preferences/com.apple.AMPLibraryAgent.plist` to `/usr/local/share/homy/com.apple.AMPLibraryAgent.plist.work`

## Setup homy

- edit e.g. `/usr/local/etc/homy.json`; (3) shows a minimal automounting configuration example

(3) `homy.json` example
```json
{
  "work_ssid": "acme_mega_corp",
  "home_ssid": "tills_toller_router",
  "delay": "10",
  "templates": "/usr/local/share/homy",
  "configurations":
  [
    {
      "path": "/etc/auto_resources",
      "setup": "automount -vc",
      "teardown": "automount -u"
    }
  ]
}
```

- copy `com.tillt.homy.service.plist` to `/Library/LaunchDaemons`
- copy `examples/auto_resources.home`, `examples/auto_resources.work` and `examples/auto_resources.unknown` to e.g. `/usr/local/share/homy`
    - edit all of the above to match your demands; (4) shows an example setup

(4) `auto_resources.home` example
```
Library -fstype=smbfs,soft,noowners,noatime,nosuid smb://till:secret@stash/Library
Downloads -fstype=smbfs,soft,noowners,noatime,nosuid smb://till:secret@stash/downloads
```

## Launch homy

- launch homy as shown in (5)
- check the homy log output (6)

(5) launch homy
```bash
sudo launchctl load /Library/LaunchDaemons/com.tillt.homy.service.plist
```

(6) check logging
```bash
tail -f /usr/local/var/log/homy.log
```

## homy CLI

| Arg. | Type     | Description            |
| ---- | -------- | ---------------------- |
| `-c` | PATH     | configuration location |
