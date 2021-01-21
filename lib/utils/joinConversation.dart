import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'package:phoenix_socket/phoenix_socket.dart';

import '../models/message.dart';
import 'dart:async';

/// This function will join the channel and listen to new messages.
PhoenixChannel joinConversationAndListen({
  List<PapercupsMessage> messages,
  @required String convId,
  @required PhoenixChannel conversation,
  @required PhoenixSocket socket,
  Function setState,
  StreamController<List<PapercupsMessage>> controller,
  @required Function setChannel,
}) {
  // Adding the channel.
  conversation = socket.addChannel(topic: "conversation:" + convId);
  // Joining channel.
  conversation.join();
  // Function to set the channel.
  setChannel(conversation);
  // Add the listener that will check for new messages.
  conversation.messages.listen(
    (event) {
      if (event.payload != null) {
        if (event.payload["status"] == "error") {
          // If there is an error, shutdown the channels and remove it.
          conversation.close();
          socket.removeChannel(conversation);
          conversation = null;
        } else {
          if (event.event.toString().contains("shout") ||
              event.event.toString().contains("message:created")) {
            // https://github.com/papercups-io/papercups/pull/488
            // "message:created" is still not implemented see the PR above.
            if (event.payload["customer"] == null) {
              var msg = PapercupsMessage(
                accountId: event.payload["account_id"],
                body: event.payload["body"].toString().trim(),
                conversationId: event.payload["conversation_id"],
                customerId: event.payload["customer_id"],
                id: event.payload["id"],
                user: (event.payload["user"] != null)
                    ? User(
                        email: event.payload["user"]["email"],
                        id: event.payload["user"]["id"],
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
                userId: event.payload["user_id"],
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

              if (controller != null) {
                controller.add([msg]);
              } else {
                setState(() {
                  messages.add(msg);
                  // } else {
                  //   var idxToUpdate = messages.indexWhere((element) {
                  //     var sentTime = element.sentAt;
                  //     sentTime = DateTime(sentTime.year, sentTime.month, sentTime.day, sentTime.hour, sentTime.second).toUtc();
                  //     print(sentTime);
                  //     return  sentTime ==
                  //         DateTime.tryParse(event.payload["sent_at"]);
                  //   });
                  //   if (idxToUpdate != -1) {
                  //     messages.removeAt(idxToUpdate);
                  //     messages.insert(
                  //       idxToUpdate,
                  //       PapercupsMessage(
                  //         accountId: event.payload["account_id"],
                  //         body: event.payload["body"].toString().trim(),
                  //         conversationId: event.payload["conversation_id"],
                  //         customerId: event.payload["customer_id"],
                  //         id: event.payload["id"],
                  //         user: (event.payload["user"] != null)
                  //             ? User(
                  //                 email: event.payload["user"]["email"],
                  //                 id: event.payload["user"]["id"],
                  //                 role: event.payload["user"]["role"],
                  //                 fullName:
                  //                     (event.payload["user"]["full_name"] != null)
                  //                         ? event.payload["user"]["full_name"]
                  //                         : null,
                  //                 profilePhotoUrl: (event.payload["user"]
                  //                             ["profile_photo_url"] !=
                  //                         null)
                  //                     ? event.payload["user"]["profile_photo_url"]
                  //                     : null,
                  //               )
                  //             : null,
                  //         customer: (event.payload["customer"] != null)
                  //             ? PapercupsCustomer(
                  //                 email: event.payload["customer"]["email"],
                  //                 id: event.payload["customer"]["id"],
                  //               )
                  //             : null,
                  //         userId: event.payload["user_id"],
                  //         createdAt: event.payload["created_at"] != null
                  //             ? DateTime.tryParse(event.payload["created_at"])
                  //             : null,
                  //         seenAt: event.payload["seen_at"] != null
                  //             ? DateTime.tryParse(event.payload["seen_at"])
                  //             : null,
                  //         sentAt: event.payload["sent_at"] != null
                  //             ? DateTime.tryParse(event.payload["sent_at"])
                  //             : null,
                  //       ),
                  //     );
                  //   }
                }, animate: true);
              }
            }
          }
        }
      }
    },
  );
  return conversation;
}
