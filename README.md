# Prayer Widgets (iPhone)

Home-screen widget that shows a mosque's prayer times, read from Prayer Widgets Studio (https://prayer-widgets-studio.vercel.app).
No login, no secrets in this repo. Times come from the public API; when the network fails the widget shows the last real answer with its age, never made-up times.

- `Sources/Shared`: models, API client, time maths (tested with `swift test`).
- `Sources/App`: the app (mosque list, today's times, how to add the widget).
- `Sources/Widget`: the widget with its mosque picker.
- `project.yml`: XcodeGen recipe; CI generates the Xcode project.
