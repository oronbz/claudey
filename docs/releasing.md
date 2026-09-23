# Releasing

Shepherd ships as a zipped `Shepherd.app` on this repository's GitHub Releases,
installed by the `shepherd` cask in [oronbz/tap](https://github.com/oronbz/homebrew-tap).
The app stays ad-hoc signed, like Sitter and Cousebara.

One number names a release: the app's `MARKETING_VERSION` (every target in
`Shepherd/Shepherd.xcodeproj`), the `version` in `plugin/herdr-plugin.toml`, the
`v`-prefixed tag, and the cask's `version`.

1. On `main`, set the new version in the Xcode project and the plugin manifest
   and commit.
2. Build the zip:

   ```bash
   tools/release.sh
   ```

   It refuses to run while the app's version and the manifest's disagree,
   builds the Release configuration from scratch, zips the app with its bundle
   metadata into `.build/release/Shepherd.zip`, and prints the zip's sha256.
3. Tag and publish the GitHub Release with the zip:

   ```bash
   git tag v<version> && git push origin v<version>
   gh release create v<version> .build/release/Shepherd.zip --title "Shepherd v<version>" --generate-notes
   ```

4. In the tap, set `version` and `sha256` in `Casks/shepherd.rb`, then check
   and publish it:

   ```bash
   brew style Casks/shepherd.rb
   brew audit --cask --online oronbz/tap/shepherd
   git commit -am "Update shepherd to <version>" && git push
   ```

5. Run the Homebrew checks in [manual verification](manual-verification.md).

`brew install --cask oronbz/tap/shepherd` installs him into `/Applications`.
A plain `brew uninstall --cask shepherd` quits him before removing the app;
adding `--zap` also removes `~/Library/Application Support/Shepherd` and his
preferences. Ghostty's Automation permission is left as it is. Homebrew's
`depends_on macos:` only names major releases, so the cask asks for Tahoe (26)
while the app itself needs 26.6.

A Homebrew install and a developer install (`tools/install.sh`) must not
coexist: both copies share the bundle id `com.oronbz.Shepherd`, and Herdr
refuses to install the plugin over the linked one. Run `tools/uninstall.sh`
before installing the cask, and `brew uninstall --zap --cask shepherd` before
going back to a developer install.
