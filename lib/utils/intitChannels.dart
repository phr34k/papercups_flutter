// Imports
import '../models/models.dart';
import '../papercups_flutter.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'dart:async';

/// This function creates the necessary channels, sockets and rooms for papercups to communicate.
initChannels(
  bool _connected,
  PhoenixSocket _socket,
  PhoenixChannel _channel,
  Props props,
  bool _canJoinConversation,
  Function setState,
) {
  if (_connected & _socket.channels.isEmpty) {
    _channel = _socket.addChannel(
      topic: 'room:' + props.accountId,
    );
    _channel.join().onReply(
      "ok",
      (res) {
        if (res.isOk && !_canJoinConversation) {
          _canJoinConversation = true;
        }
      },
    );
  }
}

/// This function creates the necessary channels, sockets and rooms for papercups to communicate.
initChannelsEx(
  PhoenixSocket _socket,
  Props props,
  Completer<bool> completer,
) {
  PhoenixChannel _channel;
  String channelName = 'room:' + props.accountId;
  if (_socket != null) {
    // Get the channel if it didn't exist already...
    if (_socket.channels.isEmpty ||
        !_socket.channels.containsKey(channelName)) {
      _channel = _socket.addChannel(topic: channelName);
      _channel.join().onReply(
        "ok",
        (res) {
          if (completer != null) completer.complete();
        },
      );
    }
    // Otherwise return the existing channel
    else {
      _channel = _socket.channels[channelName];
    }
  }
}
