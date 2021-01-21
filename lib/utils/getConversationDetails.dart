// Imports
import 'dart:convert';

import 'package:http/http.dart';
import '../models/models.dart';

/// This function will get the conversation details that we need in order to join the room.
/// The most important detail is the ID, and this will return a **new** conversation.
Future<Conversation> getConversationDetails(
  Props p,
  Conversation conv,
  PapercupsCustomer customer,
  Function sc, {
  Client client,
}) async {
  if (client == null) {
    client = Client();
  }

  try {
    print("getConversationDetails ${customer.id} ${customer.externalId}");
    var res = await client.post(
      "https://" + p.baseUrl + "/api/conversations",
      headers: {
        "content-type": "application/json",
      },
      body: jsonEncode(
        {
          "conversation": {
            "account_id": p.accountId,
            "customer_id": customer.id,
          },
        },
      ),
    );

    var data = jsonDecode(res.body)["data"];
    conv = Conversation(
      id: data["id"],
      customerId: data["customer_id"],
      accountId: data["account_id"],
      asigneeId: data["asignee_id"],
      createdAt: data["created_at"],
      read: data["read"],
      messages: [],
    );
    sc(conv);
  } catch (e) {
    conv = null;
  }
  client.close();
  return conv;
}
