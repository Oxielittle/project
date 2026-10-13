import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_config.dart';
import 'session_service.dart';

class RealtimeService {
  io.Socket? _socket;
  Future<void> connect(void Function() onChanged) async {
    final token = await SessionService.token();
    _socket = io.io(
      ApiConfig.api.replaceFirst('/api', ''),
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    for (final event in [
      'task:changed',
      'task:deleted',
      'project:changed',
      'team:changed',
      'activity-assignment:changed',
      'notification:new',
    ]) {
      _socket!.on(event, (_) => onChanged());
    }
    _socket!.connect();
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
