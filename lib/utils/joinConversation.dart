import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'package:logging/logging.dart';
import '../models/message.dart';
import 'dart:async';

/// This function will join the channel and listen to new messages.
PhoenixChannel joinConversationAndListenEx({
  @required String convId,
  @required PhoenixSocket socket,
  StreamController<PaperCupsConversationEvent> eventsController,
  StreamController<List<PapercupsMessage>> controller,
}) {
  final _logger = Logger('papercups.channel');

  // Adding the channel.
  PhoenixChannel conversation =
      socket.addChannel(topic: "conversation:" + convId);
  // Joining channel.
  conversation.join();

  // Give out information to the event
  eventsController.add(PaperCupsConversationConnectedEvent(
      conversationId: convId, channel: conversation));

  // Add the listener that will check for new messages.
  conversation.messages.listen((event) {
    if (event.payload != null) {
      if (event.payload["status"] == "error") {
        // If there is an error, shutdown the channels and remove it.
        //conversation.close();
      } else {
        if (event.event.toString().contains("shout") ||
            event.event.toString().contains("message:created")) {
          try {
            // https://github.com/papercups-io/papercups/pull/488
            // "message:created" is still not implemented see the PR above.
            if (event.payload["customer"] == null) {
              var msg = PapercupsMessage(
                accountId: event.payload["account_id"],
                body: event.payload["body"].toString().trim(),
                conversationId: event.payload["conversation_id"],
                customerId: event.payload["customer_id"] != null
                    ? event.payload["customer_id"].toString()
                    : null,
                id: event.payload["id"],
                user: (event.payload["user"] != null)
                    ? User(
                        email: event.payload["user"]["email"],
                        id: event.payload["user"]["id"] != null
                            ? event.payload["user"]["id"].toString()
                            : null,
                        role: event.payload["user"]["role"],
                        fullName: (event.payload["user"]["full_name"] != null)
                            ? event.payload["user"]["full_name"]
                            : null,
                        profilePhotoUrl:
                            (event.payload["user"]["profile_photo_url"] != null)
                                ? event.payload["user"]["profile_photo_url"]
                                : null,
                      )
                    : null,
                customer: (event.payload["customer"] != null)
                    ? PapercupsCustomer(
                        email: event.payload["customer"]["email"],
                        id: event.payload["customer"]["id"],
                      )
                    : null,
                userId: int.parse(event.payload["user_id"].toString()),
                createdAt: event.payload["created_at"] != null
                    ? DateTime.tryParse(event.payload["created_at"])
                    : null,
                seenAt: event.payload["seen_at"] != null
                    ? DateTime.tryParse(event.payload["seen_at"])
                    : null,
                sentAt: event.payload["sent_at"] != null
                    ? DateTime.tryParse(event.payload["sent_at"])
                    : null,
              );

              controller.add([msg]);
            }
          } catch (e) {
            _logger.log(Level.SEVERE, e.toString());
            eventsController.addError(e);
          }
        }
      }
    }
  }, onDone: () {
    socket.removeChannel(conversation);
    eventsController.add(PaperCupsConversationDisconnectedEvent(
        conversationId: convId, channel: conversation));
    eventsController.close();
    conversation = null;
  }, onError: (error) {
    eventsController.addError(error);
  });
  return conversation;
}
