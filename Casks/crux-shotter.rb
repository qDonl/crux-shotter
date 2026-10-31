cask "crux-shotter" do
  version "0.0.3-alpha"
  sha256 "b2f3f3a5cd258659da52ff0764efc88799dcddf9a939e74b9504303a48f98efd"

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
