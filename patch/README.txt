StoryNow builder-mode patch for Windows
=======================================

1. Close StoryNow.
2. Double-click StoryNowBuilderMode.msi.

The installer searches the Steam libraries registered on this PC for the exact
install folder steamapps\common\SN. If it finds SN, it creates the empty file:

    SN\data\builder\builder

The MSI contains no PowerShell or batch scripts, downloads nothing, and is a
per-user package that does not request administrator access. Windows Installer
records its installed state under the current user's registry so that the patch
can be uninstalled normally.

Windows may still warn about an unsigned file downloaded from the Internet.
That warning can only be addressed legitimately by Authenticode-signing the MSI
with a certificate trusted by Windows; it cannot safely be disabled by the
installer itself.
