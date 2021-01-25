//Imports
import 'updateUserMetadata.dart';
import '../models/models.dart';
import '../papercups_flutter.dart';
import 'dart:async';
import 'dart:core';
import 'getCustomerDetailsFromMetadata.dart';
import 'getPastCustomerMessages.dart';
import 'dart:developer' as developer;

String findLastConversationId(Map<String, Conversation> msgs) {
  List<PapercupsMessage> messages = [];

  msgs.forEach((key, value) {
    messages.addAll(value.messages);
  });

  messages.sort((a, b) {
    return a.createdAt.compareTo(b.createdAt);
  });

  return messages[0].conversationId;
}

class Inbox {
  bool failed;
  String conversationId;
  Map<String, Conversation> conversations;

  Inbox({
    this.conversationId,
    this.conversations,
  });
}

/// This function is used to get the history.
/// It also initializes the necessary funtions if the customer is known.
Future<Inbox> getCustomerHistoryEx({
  Props p,
  PapercupsCustomer c,
  Function setCustomer,
}) async {
  var result = Inbox();
  var failed = true;
  try {
    // Get customer details.
    var customer = await getCustomerDetailsFromMetadata(
      p,
      c,
      setCustomer,
    );
    if (customer != null) failed = false;
    if (customer != null && customer.id != null) {
      developer.log("getPastCustomerMessagesEx",
          level: 0, name: 'papercups.controller');

      // If customer is not null and there is an ID get the past messages.
      var data = await getPastCustomerMessagesEx(p, customer);
      if (data["msgs"] != null) failed = false;
      if (data["msgs"].isNotEmpty) {
        {
          // If there are messages to load sort them by date.
          //var msgsIn = ;
          //conversations.clear();
          //conversations.addAll(msgsIn);
          result.conversations = data["msgs"] as Map<String, Conversation>;
          result.conversationId = findLastConversationId(result.conversations);
        }

        /*
        // Get the first message (as we know there is at leat one messgae)
        // We use this to get the details we need to join a conversation.
        var msgToProcess = data["msgs"][0] as PapercupsMessage;
        joinConversationAndListen(
          convId: msgToProcess.conversationId,
          conversation: conversationChannel,
          setChannel: setConversationChannel,
          setState: rebuild,
          socket: socket,
          messages: messages,
        );
        */
      } else {
        result.conversations = {};
        result.conversationId = null;
      }

      developer.log("updateUserMetadataEx",
          level: 0, name: 'papercups.controller');
      if (data["cust"] != null && data["cust"] != customer) {
        // Determine if we need to update the customer details.
        var nCust =
            await updateUserMetadataEx(p, PapercupsCustomer(), data["cust"].id);
        if (nCust == null) {
          // Will only return null if the update failed.
          failed = true;
        } else if (nCust != customer) {
          // If the new customer is different then we update the details we have.
          setCustomer(nCust);
          //rebuild(() {}, animate: true);
        }
      }
    }
  } catch (e) {
    developer.log("Error on inbox $e ${e}",
        level: 0, name: 'papercups.controller');
    failed = true;
  }

  result.failed = failed;
  return result;
}
