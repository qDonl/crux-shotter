cask "crux-shotter" do
  version "0.0.2-alpha"
  sha256 "93b995431d82932efb8e7c1a15582f6455f73a7c967983da064e21be59f1f25a"

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
