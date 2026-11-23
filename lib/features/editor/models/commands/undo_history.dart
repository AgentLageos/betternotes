import 'command.dart';

/// Undo history: a list of commands and the number of them that are done ([index]); the commands
/// after [index] were undone and can be redone.
typedef UndoHistory = ({List<Command> commands, int index});

/// [history] with [newCommands] pushed: undone commands are dropped, and the oldest commands go
/// when there are more than [maxCommands].
UndoHistory pushCommands(UndoHistory history, List<Command> newCommands, int maxCommands) {
  var commands = [...history.commands.take(history.index), ...newCommands];
  if (commands.length > maxCommands) {
    commands = commands.sublist(commands.length - maxCommands);
  }
  return (commands: commands, index: commands.length);
}
