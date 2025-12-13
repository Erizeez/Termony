@Entry
@ComponentV2
struct SettingsPage {
  controller?: CustomDialogController

  build() {
    Text("Settings Page")
      .fontSize(18)
      .padding(20)
  }
}

export { SettingsPage }