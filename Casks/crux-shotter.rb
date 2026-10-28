cask "crux-shotter" do
  version "0.0.1"
  sha256 "REPLACE_WITH_DMG_SHA256"

  url "https://github.com/qDonl/crux-shotter/releases/download/v#{version}/CruxShotter-#{version}.dmg"
  name "CruxShotter"
  desc "Menu-bar screenshot, annotation, pin and OCR app"
  homepage "https://github.com/qDonl/crux-shotter"

  depends_on macos: ">= :sonoma"

  app "CruxShotter.app"

  zap trash: [
    "~/Library/Preferences/com.cruxshot.CruxShot.plist",
  ]
end
