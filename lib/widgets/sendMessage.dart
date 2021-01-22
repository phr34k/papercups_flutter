//Imports
import 'dart:async';

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/conversation.dart';
import '../models/customer.dart';
import 'package:phoenix_socket/phoenix_socket.dart';

import '../models/classes.dart';

/// Send message text box.
class SendMessage extends StatefulWidget {
  SendMessage({
    Key key,
    this.customer,
    this.setCustomer,
    this.setConversation,
    this.conversationChannel,
    this.setConversationChannel,
    this.conversation,
    this.socket,
    this.setState,
    this.messages,
    this.sending,
    @required this.props,
    @required this.textBalck,
    this.showDivider = true,
    this.controller,
  }) : super(key: key);

  final Props props;
  final PapercupsCustomer customer;
  final Function setCustomer;
  final Function setState;
  final Function setConversation;
  final Function setConversationChannel;
  final PhoenixChannel conversationChannel;
  final Conversation conversation;
  final PhoenixSocket socket;
  final List<PapercupsMessage> messages;
  final StreamController<PapercupsMessage> controller;
  final bool sending;
  final bool textBalck;
  final bool showDivider;

  @override
  _SendMessageState createState() => _SendMessageState();
}

class _SendMessageState extends State<SendMessage> {
  final _msgController = TextEditingController();

  final _msgFocusNode = FocusNode();

  @override
  void dispose() {
    _msgController.dispose();
    _msgFocusNode.dispose();
    super.dispose();
  }

  void triggerSend() {
    _sendMessage(
      _msgFocusNode,
      _msgController,
      widget.customer,
      widget.props,
      widget.setCustomer,
      widget.conversation,
      widget.setConversation,
      widget.setConversationChannel,
      widget.conversationChannel,
      widget.socket,
      widget.setState,
      widget.messages,
      widget.sending,
      widget.controller,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: 55,
      ),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: widget.showDivider
              ? Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                )
              : null,
          boxShadow: [
            BoxShadow(
                blurRadius: 30,
                color: Theme.of(context).shadowColor.withOpacity(0.1))
          ]),
      child: Padding(
        padding: const EdgeInsets.only(left: 15, right: 0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: widget.props.newMessagePlaceholder,
                  hintStyle: const TextStyle(
                    fontSize: 14,
                  ),
                ),
                onSubmitted: (_) => triggerSend(),
                controller: _msgController,
                focusNode: _msgFocusNode,
              ),
            ),
            Container(
              height: 36,
              width: 36,
              margin: EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: widget.props.primaryColor,
                gradient: widget.props.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: InkWell(
                customBorder: CircleBorder(),
                onTap: triggerSend,
                child: Icon(
                  Icons.send,
                  color: widget.textBalck ? Colors.black : Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Send message function
void _sendMessage(
  FocusNode fn,
  TextEditingController tc,
  PapercupsCustomer cu,
  Props p,
  Function setCust,
  Conversation conv,
  Function setConv,
  Function setConvChannel,
  PhoenixChannel conversationChannel,
  PhoenixSocket socket,
  Function setState,
  List<PapercupsMessage> messages,
  bool sending,
  StreamController<PapercupsMessage> controller,
) {
  final text = tc.text;
  fn.requestFocus();
  if (text.trim().isEmpty || text == null) return null;
  tc.clear();
  var timeNow = DateTime.now();
  var msg = PapercupsMessage(
    body: text,
    createdAt: timeNow,
    sentAt: timeNow,
    customer: PapercupsCustomer(),
  );

  if (controller != null) {
    controller.add(msg);
    return;
  }
}
