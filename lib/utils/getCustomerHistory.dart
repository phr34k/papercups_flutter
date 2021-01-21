//Imports
import 'updateUserMetadata.dart';

import '../models/models.dart';
import '../papercups_flutter.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'dart:async';
import 'dart:core';

import 'getCustomerDetailsFromMetadata.dart';
import 'getPastCustomerMessages.dart';
import 'joinConversation.dart';

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

/// This function is used to get the history.
/// It also initializes the necessary funtions if the customer is known.
Future<bool> getCustomerHistory({
  Props p,
  PapercupsCustomer c,
  Function setCustomer,
  String conversationId,
  List<PapercupsMessage> messages,
  PhoenixChannel conversationChannel,
  Function setConversationChannel,
  Function rebuild,
  PhoenixSocket socket,
}) async {
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
      // If customer is not null and there is an ID get the past messages.
      var data = await getPastCustomerMessages(p, customer,
          conversationId: conversationId);
      if (data["msgs"] != null) failed = false;
      if (data["msgs"].isNotEmpty) {
        {
          // If there are messages to load sort them by date.
          var msgsIn = data["msgs"] as List<PapercupsMessage>;
          msgsIn.sort((a, b) {
            return a.createdAt.compareTo(b.createdAt);
          });
          // Add them to the message list.
          messages.addAll(msgsIn);
        }
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
      }
      if (data["cust"] != null && data["cust"] != customer) {
        // Determine if we need to update the customer details.
        var nCust = await updateUserMetadata(p, data["cust"].id);
        if (nCust == null) {
          // Will only return null if the update failed.
          failed = true;
        } else if (nCust != customer) {
          // If the new customer is different then we update the details we have.
          setCustomer(nCust);
          rebuild(() {}, animate: true);
        }
      }
    }
  } catch (e) {
    failed = true;
  }
  return failed;
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

      if (data["cust"] != null && data["cust"] != customer) {
        // Determine if we need to update the customer details.
        var nCust = await updateUserMetadata(p, data["cust"].id);
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
    print("exception ${e}");
    failed = true;
  }

  result.failed = failed;
  return result;
}
