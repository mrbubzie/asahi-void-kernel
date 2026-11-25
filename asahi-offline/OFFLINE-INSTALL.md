# Offline install on Void Linux for Apple Silicon

This bundle is for an existing Void Linux installation with the Asahi boot
environment already set up. Keep the entire extracted folder together. Transfer
it to the Mac, open a terminal in the folder, and run:

```sh
sh install-offline.sh
```

The installer checks the hashes and architecture, previews the XBPS transaction,
then asks for confirmation. XBPS uses the bundled repository exclusively.
The exact kernel is 7.3.6 with the Asahi 7.3.4-2 changes and local suffix +0, Void revision 1.
An installed newer kernel may require an explicit downgrade. The installer
does not force one.

Before rebooting, confirm that the package transaction and kernel hooks
completed successfully. With GRUB, confirm that the new kernel appears in the
boot menu and retain the existing kernel until the new one has booted. The
installer does not repartition the disk or run the macOS Asahi installer.
The repository includes Void's Asahi firmware tooling. Any machine-specific
Apple firmware already provisioned by your Asahi installation stays on the Mac.

After reboot, run `uname -r`. The expected release is `7.3.6+0-asahi_1`.
For built-in speaker audio, use Void's speakersafetyd service and a running
PipeWire and WirePlumber user session.
