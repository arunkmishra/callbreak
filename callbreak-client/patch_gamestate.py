with open('/Users/arunkumarmishra/Workspace/callbreak/callbreak-client/lib/data/models/game_state.dart', 'r') as f:
    content = f.read()

content = content.replace("  final int? turnEndTime;\n\n  const GameState({", "  final int? turnEndTime;\n  final bool isPublic;\n\n  const GameState({")
content = content.replace("    this.turnEndTime,\n  });", "    this.turnEndTime,\n    this.isPublic = false,\n  });")
content = content.replace("        turnEndTime: json['turnEndTime'] as int?,\n      );", "        turnEndTime: json['turnEndTime'] as int?,\n        isPublic: json['isPublic'] as bool? ?? false,\n      );")

with open('/Users/arunkumarmishra/Workspace/callbreak/callbreak-client/lib/data/models/game_state.dart', 'w') as f:
    f.write(content)
