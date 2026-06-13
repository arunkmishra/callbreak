with open('/Users/arunkumarmishra/Workspace/callbreak/callbreak-client/lib/ui/screens/lobby_screen.dart', 'r') as f:
    content = f.read()

# Pass isPublic down
content = content.replace(
    "_StartGameSection(isHost: isHost, canStart: canStart),",
    "_StartGameSection(isHost: isHost, canStart: canStart, isPublic: gameState.isPublic),"
)

content = content.replace(
    "_buildHeader(BuildContext context, bool isHost, bool canStart) {",
    "_buildHeader(BuildContext context, bool isHost, bool canStart, bool isPublic) {"
)
content = content.replace(
    "_buildHeader(context, isHost, canStart)",
    "_buildHeader(context, isHost, canStart, gameState.isPublic)"
)

# Update _StartGameSection definition
section_orig = """class _StartGameSection extends StatelessWidget {
  final bool isHost;
  final bool canStart;
  const _StartGameSection({required this.isHost, required this.canStart});"""
section_repl = """class _StartGameSection extends StatelessWidget {
  final bool isHost;
  final bool canStart;
  final bool isPublic;
  const _StartGameSection({required this.isHost, required this.canStart, this.isPublic = false});"""
content = content.replace(section_orig, section_repl)

# Update _StartGameSection text
text_orig = """                    isHost ? 'START GAME' : 'WAITING FOR HOST TO START...','""'
text_repl = """                    isPublic ? 'WAITING FOR PLAYERS...' : (isHost ? 'START GAME' : 'WAITING FOR HOST TO START...'),"""
content = content.replace("isHost ? 'START GAME' : 'WAITING FOR HOST TO START...',", text_repl)

# Update opacity and onPressed
opacity_orig = """opacity: (isHost && canStart) ? 1.0 : 0.5,"""
opacity_repl = """opacity: (!isPublic && isHost && canStart) ? 1.0 : 0.5,"""
content = content.replace(opacity_orig, opacity_repl)

press_orig = """onPressed: (isHost && canStart) ? () => context.read<GameBloc>().add(const StartGameRequested()) : null,"""
press_repl = """onPressed: (!isPublic && isHost && canStart) ? () => context.read<GameBloc>().add(const StartGameRequested()) : null,"""
content = content.replace(press_orig, press_repl)

icon_orig = """if (isHost && canStart) const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                  if (isHost && canStart) const SizedBox(width: 8),"""
icon_repl = """if (!isPublic && isHost && canStart) const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                  if (!isPublic && isHost && canStart) const SizedBox(width: 8),"""
content = content.replace(icon_orig, icon_repl)

with open('/Users/arunkumarmishra/Workspace/callbreak/callbreak-client/lib/ui/screens/lobby_screen.dart', 'w') as f:
    f.write(content)
