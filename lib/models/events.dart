import 'package:papercups_flutter/models/customer.dart';
import 'package:papercups_flutter/models/conversation.dart';
import 'package:phoenix_socket/phoenix_socket.dart';

class PaperCupsEvent {}

class PaperCupsConnectionEvent extends PaperCupsEvent {}

class PaperCupsConnectedEvent extends PaperCupsConnectionEvent {}

class PaperCupsDisconnectedEvent extends PaperCupsConnectionEvent {}

class PaperCupsCustomerIdentifiedEvent extends PaperCupsEvent {
  PapercupsCustomer customer;
  bool rebuild;
  PaperCupsCustomerIdentifiedEvent(this.customer, this.rebuild);
}

class PaperCupsConversationNavigatedEvent extends PaperCupsEvent {
  Conversation conversation;
  bool rebuild;
  PaperCupsConversationNavigatedEvent(this.conversation, this.rebuild);
}

class PaperCupsSessionIdentifiedEvent extends PaperCupsEvent {}

class PaperCupsConversationStartedEvent extends PaperCupsEvent {}

class PaperCupsConversationClosedEvent extends PaperCupsEvent {}

class PaperCupsConversationMessageReceivedEvent extends PaperCupsEvent {}

class PaperCupsConversationMessageSendEvent extends PaperCupsEvent {}

class PaperCupsConversationEvent extends PaperCupsEvent {
  final String conversationId;
  final PhoenixChannel channel;
  PaperCupsConversationEvent({
    this.channel,
    this.conversationId,
  });
}

class PaperCupsConversationFinishedEvent extends PaperCupsEvent {}

class PaperCupsConversationUnloadEvent extends PaperCupsConversationEvent {
  final String conversationId;
  final PhoenixChannel channel;
  PaperCupsConversationUnloadEvent({
    this.channel,
    this.conversationId,
  });
}

class PaperCupsConversationLoadEvent extends PaperCupsConversationEvent {
  final String conversationId;
  final PhoenixChannel channel;
  PaperCupsConversationLoadEvent({
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
