# Try the app on an iPhone, without a Mac

GitHub's Mac builds the iPhone app on every run of the **iOS TestFlight**
workflow, and publishes it as `hssan-delivery.ipa` on the **ios-latest**
pre-release:

<https://github.com/Alibalti592/Hssan-Delivery/releases/download/ios-latest/hssan-delivery.ipa>

That `.ipa` is unsigned: an iPhone won't open it as is. [xtool](https://github.com/xtool-org/xtool)
signs it with your Apple ID and installs it, from **Linux** or **Windows (WSL)**,
with the iPhone plugged in by USB.

Good to know:

- **Free Apple ID:** the app stops opening after **7 days**; install it again
  to renew. At most 3 apps installed this way at once. **No push
  notifications**: free accounts can't use them, and xtool drops that
  permission when it signs.
- **Paid Apple Developer account ($99/year):** the app lasts a year and push
  works. That same account also unlocks TestFlight (see
  `.github/workflows/ios-testflight.yml`), the real way to give the app to
  others.
- xtool signs in to Apple through unofficial APIs with a password. Using a
  separate Apple ID just for this is the cautious choice.

## Once: install xtool

On Windows, first install **WSL** (Ubuntu) and **USBIPD**, so that the iPhone
plugged into the PC can be passed to WSL: Microsoft's guide
<https://learn.microsoft.com/en-us/windows/wsl/connect-usb>. Then run the
rest inside WSL.

```bash
sudo apt-get install -y usbmuxd libimobiledevice-utils

curl -fL "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" -o xtool
chmod +x xtool && sudo mv xtool /usr/local/bin/
xtool --help
```

If `xtool --help` complains about FUSE, run `sudo apt-get install -y libfuse2`
and try again.

Log in to Apple (only this, not the full `xtool setup`: Swift and Xcode.xip
are for building Swift apps, which isn't needed to install ours):

```bash
xtool auth login
# 0: API key       (paid developer account)
# 1: Password      (any Apple ID; asks for the 2FA code)
```

## Each time: install the latest build

1. Plug the iPhone in by USB, unlock it, and tap **Trust** on "Trust this
   computer?". On Windows, attach it to WSL with `usbipd attach --wsl`
   (see Microsoft's guide).
2. Then:

```bash
curl -fL https://github.com/Alibalti592/Hssan-Delivery/releases/download/ios-latest/hssan-delivery.ipa -o hssan-delivery.ipa
xtool devices                      # the iPhone must be listed
xtool install hssan-delivery.ipa
```

3. The first time, on the iPhone:
   - **Settings → Privacy & Security → Developer Mode → On**, then restart
     when asked (iOS 16 and later).
   - **Settings → General → VPN & Device Management**: tap your Apple ID,
     then **Trust**.

Open **Delivery Hassen**.

## A new build

Each merge to `main` that touches the app rebuilds it. To build from another
branch (e.g. `dev`), go to GitHub → **Actions → iOS TestFlight → Run
workflow** and pick the branch. About 15 minutes later, `ios-latest` has the
new `.ipa`: run step 2 again.

The app talks to the API set by the repository variable `API_BASE_URL`
(Railway until it's set).

## If something goes wrong

- **`xtool devices` lists nothing:** check the cable, unlock the iPhone and
  tap Trust. Run `sudo systemctl restart usbmuxd`. On WSL, run
  `usbipd attach --wsl` again.
- **On WSL, `AFCClient.Error.muxError`:** see
  <https://github.com/xtool-org/xtool/issues/19#issuecomment-2898986718>.
- **"Untrusted developer" when opening the app:** do step 3 (VPN & Device
  Management).
- **The app opened before, not anymore (free Apple ID):** the 7 days are
  over. Install again (step 2).
