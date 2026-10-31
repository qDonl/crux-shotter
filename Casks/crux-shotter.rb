cask "crux-shotter" do
  version "0.0.4-alpha"
  sha256 "9b4e0a09761d4a5ba91310b03874a573aee43147c79b2b7d4d4789db03452215"

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
