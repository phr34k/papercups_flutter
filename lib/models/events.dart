import 'package:phoenix_socket/phoenix_socket.dart';

class PaperCupsEvent {}

class PaperCupsConnectedEvent extends PaperCupsEvent {}

class PaperCupsDisconnectedEvent extends PaperCupsEvent {}

class PaperCupsSessionIdentifiedEvent extends PaperCupsEvent {}

class PaperCupsConversationStartedEvent extends PaperCupsEvent {}

class PaperCupsConversationClosedEvent extends PaperCupsEvent {}

class PaperCupsConversationLoadEvent extends PaperCupsEvent {}

class PaperCupsConversationMessageReceivedEvent extends PaperCupsEvent {}

class PaperCupsConversationMessageSendEvent extends PaperCupsEvent {}

class PaperCupsConversationFinishedEvent extends PaperCupsEvent {}

class PaperCupsConversationEvent extends PaperCupsEvent {
  final String conversationId;
  final PhoenixChannel channel;
  PaperCupsConversationEvent({
    this.channel,
    this.conversationId,
  });
}

class PaperCupsConversationConnectedEvent extends PaperCupsConversationEvent {
  PaperCupsConversationConnectedEvent({
    PhoenixChannel channel,
    String conversationId,
  }) : super(channel: channel, conversationId: conversationId);
}

class PaperCupsConversationDisconnectedEvent
    extends PaperCupsConversationEvent {
  PaperCupsConversationDisconnectedEvent({
    PhoenixChannel channel,
    String conversationId,
  }) : super(channel: channel, conversationId: conversationId);
}

class PaperCupsConversationMessageStatusEvent
    extends PaperCupsConversationEvent {
  PaperCupsConversationMessageStatusEvent({
    PhoenixChannel channel,
    String conversationId,
  }) : super(channel: channel, conversationId: conversationId);
}

class PaperCupsConversationMessageSending
    extends PaperCupsConversationMessageStatusEvent {
  PaperCupsConversationMessageSending({
    PhoenixChannel channel,
    String conversationId,
  }) : super(channel: channel, conversationId: conversationId);
}

class PaperCupsConversationMessageDone
    extends PaperCupsConversationMessageStatusEvent {
  PaperCupsConversationMessageDone({
    PhoenixChannel channel,
    String conversationId,
  }) : super(channel: channel, conversationId: conversationId);
}
