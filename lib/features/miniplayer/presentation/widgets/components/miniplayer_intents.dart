import 'package:flutter/widgets.dart';

/// Keyboard intents for the floating and expanded miniplayer modes.

class MiniplayerExpandIntent extends Intent {
  const MiniplayerExpandIntent();
}

class MiniplayerDismissIntent extends Intent {
  const MiniplayerDismissIntent();
}

class MiniplayerCollapseIntent extends Intent {
  const MiniplayerCollapseIntent();
}

class MiniplayerTogglePlayIntent extends Intent {
  const MiniplayerTogglePlayIntent();
}

class MiniplayerSeekBackwardIntent extends Intent {
  const MiniplayerSeekBackwardIntent();
}

class MiniplayerSeekForwardIntent extends Intent {
  const MiniplayerSeekForwardIntent();
}
