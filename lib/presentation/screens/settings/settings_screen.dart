class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: const [
          SwitchListTile(title: Text("Show Grid Overlay"), value: true, onChanged: null),
          SwitchListTile(title: Text("Enable AI Guidance (Placeholder)"), value: false, onChanged: null),
          SwitchListTile(title: Text("Enable Dark Mode"), value: false, onChanged: null),
        ],
      ),
    );
  }
}
