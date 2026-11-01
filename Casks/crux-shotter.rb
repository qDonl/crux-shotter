cask "crux-shotter" do
  version "0.0.10-alpha"
  sha256 "5060f7fe27067edf845dc6f7bcc1eead4b0a5a7aa75402c1ee8f02d331de29aa"

  url "https://github.com/qDonl/crux-shotter/releases/download/v#{version}/CruxShotter-#{version}.dmg"
  name "CruxShotter"
  desc "Menu-bar screenshot, annotation, pin and OCR app"
  homepage "https://github.com/qDonl/crux-shotter"

  depends_on macos: ">= :sonoma"

  app "CruxShotter.app"

  uninstall quit: "com.cruxshot.CruxShot"

  zap trash: [
    "~/Library/Preferences/com.cruxshot.CruxShot.plist",
  ]
end
