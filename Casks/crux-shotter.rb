cask "crux-shotter" do
  version "0.0.9-alpha"
  sha256 "22820d02dc3866bf09ad109ab4cf74ee573135e482df4f1323c59768a0611e56"

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
