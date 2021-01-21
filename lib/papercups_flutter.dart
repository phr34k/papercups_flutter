library papercups_flutter;

// Imports.
import 'package:flutter/material.dart';
import 'utils/utils.dart';
import 'widgets/widgets.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'models/models.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';

// Exports.
export 'models/classes.dart';
export 'package:timeago/timeago.dart';

/// Returns the webview which contains the chat. To use it simply call PaperCupsWidget(), making sure to add the props!
class PaperCupsWidget extends StatefulWidget {
  /// Initialize the props that you will pass on PaperCupsWidget.
  final Props props;

  /// Locale for the date, use the locales from the `intl` package.
  /// For example `"es"` or `"en-UK"`.
  final String dateLocale;

  /// Locale for the fuzzy timestamps. Check timeago locales. For example `EsMessages()`.
  /// Check https://github.com/andresaraujo/timeago.dart/tree/master/timeago/lib/src/messages
  /// for the available classes.
  final timeagoLocale;

  /// Text to show while message is sending. Default `"Sending..."`
  final String sendingText;

  /// Text to show when the messgae is sent. Default is `"Sent"` time will be added after.
  final String sentText;

  /// If not null, close button will be shown.
  final Function closeAction;

  /// Set to true in order to make the send message section float
  final bool floatingSendMessage;

  PaperCupsWidget({
    @required this.props,
    this.dateLocale = "en-US",
    this.timeagoLocale,
    this.sendingText = "Sending...",
    this.sentText = "Sent",
    this.closeAction,
    this.floatingSendMessage = false,
  });

  @override
  _PaperCupsWidgetState createState() => _PaperCupsWidgetState();
}

class PaperCupsWidgetB extends StatefulWidget {
  /// Initialize the props that you will pass on PaperCupsWidget.
  final Props props;

  /// Locale for the date, use the locales from the `intl` package.
  /// For example `"es"` or `"en-UK"`.
  final String dateLocale;

  /// Locale for the fuzzy timestamps. Check timeago locales. For example `EsMessages()`.
  /// Check https://github.com/andresaraujo/timeago.dart/tree/master/timeago/lib/src/messages
  /// for the available classes.
  final timeagoLocale;

  /// Text to show while message is sending. Default `"Sending..."`
  final String sendingText;

  /// Text to show when the messgae is sent. Default is `"Sent"` time will be added after.
  final String sentText;

  /// If not null, close button will be shown.
  final Function closeAction;

  /// Set to true in order to make the send message section float
  final bool floatingSendMessage;

  PaperCupsWidgetB({
    @required this.props,
    this.dateLocale = "en-US",
    this.timeagoLocale,
    this.sendingText = "Sending...",
    this.sentText = "Sent",
    this.closeAction,
    this.floatingSendMessage = false,
  });

  @override
  _PaperCupsWidgetState2 createState() => _PaperCupsWidgetState2();
}

class _PaperCupsWidgetState extends State<PaperCupsWidget> {
  bool _connected = false;
  PhoenixSocket _socket;
  PhoenixChannel _channel;
  PhoenixChannel _conversationChannel;
  List<PapercupsMessage> _messages = [];
  PapercupsCustomer _customer;
  bool _canJoinConversation = false;
  Conversation _conversation;
  ScrollController _controller = ScrollController();
  bool _sending = false;
  bool noConnection = false;
  bool textBlack = false;

  @override
  void initState() {
    if (widget.props.baseUrl.contains("http"))
      throw "Do not provide a protocol in baseURL";
    if (widget.props.baseUrl.endsWith("/")) throw "Do not provide a trailing /";
    if (widget.props.primaryGradient != null &&
        widget.props.primaryColor != null)
      throw "Expected either primaryColor or primaryGradient to be null";
    if (widget.props.customer != null) {
      setCustomer(PapercupsCustomer(
        email: widget.props.customer.email,
        externalId: widget.props.customer.externalId,
        name: widget.props.customer.name,
      ));
    }
    if (widget.dateLocale != "en-US") {
      initializeDateFormatting().then((_) {
        if (mounted) setState(() {});
      });
    }
    super.initState();
  }

  @override
  void dispose() {
    if (_channel != null) _channel.close();
    if (_conversationChannel != null) _conversationChannel.close();
    if (_socket != null) _socket.dispose();
    if (_controller != null) _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    if (widget.props.greeting != null) {
      _messages = [
        PapercupsMessage(
          body: widget.props.greeting,
          sentAt: DateTime.now(),
          createdAt: DateTime.now(),
          accountId: widget.props.accountId,
          user: User(
            fullName: widget.props.companyName,
          ),
          userId: 0,
          id: "greeting",
        ),
      ];
    }
    if (_socket == null) {
      _socket =
          PhoenixSocket("wss://" + widget.props.baseUrl + '/socket/websocket')
            ..connect();
      _subscribeToSocket();
    }
    if (widget.props.customer != null &&
        widget.props.customer.externalId != null &&
        (_customer == null || _customer.createdAt == null) &&
        _conversation == null) {
      getCustomerHistory(
        conversationChannel: _conversationChannel,
        c: _customer,
        messages: _messages,
        rebuild: rebuild,
        setConversationChannel: setConversationChannel,
        setCustomer: setCustomer,
        socket: _socket,
        p: widget.props,
      ).then((failed) {
        if (failed) {
          Alert.show(
            "There was an issue retrieving your details. Please try again!",
            context,
            backgroundColor: Theme.of(context).bottomAppBarColor,
            textStyle: Theme.of(context).textTheme.bodyText2,
            gravity: Alert.bottom,
            duration: Alert.lengthLong,
          );
          setState(() {
            noConnection = true;
          });
        }
      });
    }
    if ((widget.props.primaryColor != null &&
            widget.props.primaryColor.computeLuminance() > 0.5) ||
        (widget.props.primaryGradient != null &&
            widget.props.primaryGradient.colors[0].computeLuminance() > 0.5) ||
        (widget.props.primaryColor == null &&
            Theme.of(context).primaryColor.computeLuminance() > 0.5))
      textBlack = true;
    super.didChangeDependencies();
  }

  void setCustomer(PapercupsCustomer c, {rebuild = false}) {
    _customer = c;
    if (rebuild) setState(() {});
  }

  void setConversation(Conversation c) {
    _conversation = c;
  }

  void setConversationChannel(PhoenixChannel c) {
    _conversationChannel = c;
  }

  void rebuild(void Function() fn, {bool stateMsg = false, animate = false}) {
    _sending = stateMsg;
    if (mounted) setState(fn);
    if (animate &&
        mounted &&
        _messages.isNotEmpty &&
        WidgetsBinding.instance != null &&
        _controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.position.maxScrollExtent != null)
          _controller.animateTo(
            _controller.position.maxScrollExtent,
            curve: Curves.easeIn,
            duration: Duration(milliseconds: 300),
          );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    initChannels(
      _connected,
      _socket,
      _channel,
      widget.props,
      _canJoinConversation,
      rebuild,
    );
    if (widget.props.primaryColor == null &&
        widget.props.primaryGradient == null)
      widget.props.primaryColor = Theme.of(context).primaryColor;
    return Container(
      color: Theme.of(context).canvasColor,
      child: noConnection
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 100,
                    color: Colors.grey,
                  ),
                  Text(
                    "No Connection",
                    style: Theme.of(context).textTheme.headline5.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  FlatButton.icon(
                    onPressed: () {
                      if (!_socket.isConnected) {
                        _socket.dispose();
                        _socket = PhoenixSocket("wss://" +
                            widget.props.baseUrl +
                            '/socket/websocket')
                          ..connect();
                        _subscribeToSocket();
                      }
                      if (widget.props.customer != null &&
                          widget.props.customer.externalId != null &&
                          (_customer == null || _customer.createdAt == null) &&
                          _conversation == null)
                        getCustomerHistory(
                          conversationChannel: _conversationChannel,
                          c: _customer,
                          messages: _messages,
                          rebuild: rebuild,
                          setConversationChannel: setConversationChannel,
                          setCustomer: setCustomer,
                          socket: _socket,
                          p: widget.props,
                        ).then((failed) {
                          if (!failed) {
                            _socket.connect();
                            if (mounted)
                              setState(() {
                                noConnection = false;
                              });
                          }
                        });
                    },
                    icon: Icon(Icons.refresh_rounded),
                    label: Text("Retry"),
                    textColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(90),
                    ),
                  )
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Header(
                  props: widget.props,
                  closeAction: widget.closeAction,
                  textBlack: textBlack,
                ),
                // if (widget.props.showAgentAvailability)
                //   AgentAvailability(widget.props),
                Expanded(
                  child: ChatMessages(
                    widget.props,
                    _messages,
                    _controller,
                    _sending,
                    widget.dateLocale,
                    widget.timeagoLocale,
                    widget.sendingText,
                    widget.sentText,
                    textBlack,
                  ),
                ),
                if (!widget.floatingSendMessage) PoweredBy(),
                Container(
                  margin: widget.floatingSendMessage
                      ? EdgeInsets.only(
                          right: 15,
                          left: 15,
                        )
                      : null,
                  decoration: widget.floatingSendMessage
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                              BoxShadow(
                                blurRadius: 10,
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.grey.withOpacity(0.4)
                                    : Colors.black.withOpacity(0.8),
                              )
                            ])
                      : BoxDecoration(),
                  clipBehavior:
                      widget.floatingSendMessage ? Clip.antiAlias : Clip.none,
                  child: (widget.props.requireEmailUpfront &&
                          (_customer == null || _customer.email == null))
                      ? RequireEmailUpfront(setCustomer, widget.props,
                          textBlack, !widget.floatingSendMessage)
                      : SendMessage(
                          props: widget.props,
                          customer: _customer,
                          setCustomer: setCustomer,
                          setConversation: setConversation,
                          conversationChannel: _conversationChannel,
                          setConversationChannel: setConversationChannel,
                          conversation: _conversation,
                          socket: _socket,
                          setState: rebuild,
                          messages: _messages,
                          sending: _sending,
                          textBalck: textBlack,
                          showDivider: !widget.floatingSendMessage,
                        ),
                ),
                if (widget.floatingSendMessage)
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: PoweredBy(),
                  ),
              ],
            ),
    );
  }

  void _subscribeToSocket() {
    _socket.closeStream.listen((event) {
      if (mounted)
        setState(() {
          _connected = false;
          noConnection = true;
        });
    });

    _socket.openStream.listen(
      (event) {
        if (noConnection && mounted) {
          rebuild(() {
            noConnection = false;
          }, animate: true);
        }
        return _connected = true;
      },
    );
  }
}

class ConversationPair {
  final Conversation conversation;
  final PhoenixChannel channel;
  ConversationPair({
    this.conversation,
    this.channel,
  });
}

abstract class _PaperCupsMixin {
  StreamController<PapercupsMessage> _stateMessageController =
      StreamController<PapercupsMessage>();
  StreamController _stateStreamController = StreamController.broadcast();
  // ignore: unused_field
  Stream<PaperCupsConnectedEvent> _openStream;
  // ignore: unused_field
  Stream<PaperCupsDisconnectedEvent> _closeStream;

  bool _connected = false;
  PhoenixSocket _socket;
  PhoenixChannel _channel;
  PhoenixChannel _conversationChannel;
  Map<String, Conversation> _conversations = {};
  //List<PapercupsMessage> _messages = [];
  PapercupsCustomer _customer;
  bool _canJoinConversation = false;
  Conversation _conversation;
  //String _conversationId;
  bool _sending = false;
  bool noConnection = false;

  List<PapercupsMessage> _default = [];

  bool get isConnected {
    return _socket != null && _socket.isConnected;
  }

  void initStateA(Props props) {
    if (props.baseUrl.contains("http"))
      throw "Do not provide a protocol in baseURL";
    if (props.baseUrl.endsWith("/")) throw "Do not provide a trailing /";
    if (props.primaryGradient != null && props.primaryColor != null)
      throw "Expected either primaryColor or primaryGradient to be null";
    if (props.customer != null) {
      setCustomer(PapercupsCustomer(
        email: props.customer.email,
        externalId: props.customer.externalId,
        name: props.customer.name,
      ));
    }

    _openStream = _stateStreamController.stream
        .where((event) => event is PaperCupsConnectedEvent)
        .cast<PaperCupsConnectedEvent>();
    _closeStream = _stateStreamController.stream
        .where((event) => event is PaperCupsDisconnectedEvent)
        .cast<PaperCupsDisconnectedEvent>();
  }

  void ensureConnected(Props props) {
    if (_socket == null) {
      _socket = PhoenixSocket("wss://" + props.baseUrl + '/socket/websocket');

      _socket.closeStream.listen((event) {
        _connected = false;
        noConnection = true;
        ondisconnected();
        _stateStreamController.add(PaperCupsConnectedEvent());
      });

      _socket.openStream.listen(
        (event) {
          if (noConnection && mounted) {
            rebuild(() {
              noConnection = false;
            }, animate: true);
          }
          _connected = true;
          _stateStreamController.add(PaperCupsConnectedEvent());
          onconnected();
        },
      );

      _socket.connect();
    }
  }

  bool get mounted;
  void onconnected();
  void ondisconnected();
  void onconversationloaded(String conversationId);
  void onconversationunloaded(String conversationId);

  void setCustomer(PapercupsCustomer c, {rebuild = false});
  void setConversation(Conversation c);
  void setConversationChannel(PhoenixChannel c);
  void rebuild(void Function() fn, {bool stateMsg = false, animate = false});

  void disposeA() {
    if (_channel != null) _channel.close();
    if (_conversationChannel != null) _conversationChannel.close();
    if (_socket != null) _socket.dispose();
    if (_stateMessageController != null) _stateMessageController.close();
  }

  Future<PhoenixChannel> join(Conversation conversation) async {
    assert(conversation != null);
    var controller = StreamController<List<PapercupsMessage>>();
    controller.stream.listen((messages) {
      rebuild(() {
        conversation.messages.addAll(messages);
      }, animate: true);
    });

    var conv = joinConversationAndListen(
      convId: conversation.id,
      conversation: _conversationChannel,
      setChannel: setConversationChannel,
      controller: controller,
      socket: _socket,
    );

    return conv;
  }

  void goto(Props props, String conversationId) {
    if (_conversations.containsKey(conversationId)) {
      fetch(props, _conversations[conversationId], noDefaultLoad: true);
    } else {
      List<PapercupsMessage> messages = [];
      messages.addAll(_default);
      fetch(props, Conversation(messages: messages), noDefaultLoad: true);
    }
  }

  Future<bool> selectChannel(Conversation conversation) async {
    String previousConversationId =
        _conversation != null ? _conversation.id : null;
    String newConversationId = conversation != null ? conversation.id : null;
    print("selecting conversation id: ${newConversationId}");
    //_messages.clear();
    if (_conversations.containsKey(newConversationId)) {
      //_messages.addAll(_conversations[conversationId].messages);
      onconversationunloaded(previousConversationId);
      //_conversationId = conversationId;
      if (newConversationId == null) {
        print("reset messages: ${newConversationId}");
        setConversation(null);
        setConversationChannel(null);
      } else {
        print("join conversation id: ${newConversationId}");
        setConversation(_conversations[newConversationId]);
        join(_conversations[newConversationId]);
      }

      onconversationloaded(newConversationId);
      return true;
    } else {
      print("reset messages: ${newConversationId}");
      onconversationunloaded(previousConversationId);
      //_conversationId = conversationId;
      setConversation(conversation);
      setConversationChannel(null);
      onconversationloaded(newConversationId);
      return false;
    }
  }

  //Identify the customer
  Future<PapercupsCustomer> identify(Props props, {bool create = false}) {
    if (props.customer != null &&
        props.customer.externalId != null &&
        (_customer == null || _customer.createdAt == null)) {
      print("identity getCustomerDetailsFromMetadata");
      return getCustomerDetailsFromMetadata(props, _customer, setCustomer);
    } else if (_customer == null) {
      if (create == true) {
        print("identity getCustomerDetails");
        return getCustomerDetails(props, _customer, setCustomer);
      } else {
        print("identity no customer, and wasn't created");
        return Future<PapercupsCustomer>.value(_customer);
      }
    } else {
      print("identity existing customer");
      return Future<PapercupsCustomer>.value(_customer);
    }
  }

  Future<ConversationPair> getConversation(Props props, {bool joins}) async {
    if (_conversation != null) {
      return Future<ConversationPair>.value(ConversationPair(
          conversation: _conversation, channel: _conversationChannel));
    } else {
      var customerId = _customer.id;
      var completer = Completer<ConversationPair>();
      getConversationDetails(props, _conversation, _customer, setConversation)
          .then((conversationDetails) {
        assert(conversationDetails.customerId == customerId);
        //_conversationId = conversationDetails.id;
        join(conversationDetails).then((conv) {
          completer.complete(ConversationPair(
              conversation: conversationDetails, channel: conv));
        });
      });

      return completer.future;
    }
  }

  Future<bool> fetch(Props props, Conversation conversation,
      {bool noDefaultLoad = false}) {
    Completer<bool> _completer = Completer<bool>();
    print("fetch to ${conversation}");
    identify(props).then((customer) {
      if (conversation == null || conversation.id != null) {
        print("Updating customer history");
        getCustomerHistoryEx(c: _customer, p: props, setCustomer: setCustomer)
            .then((Inbox inbox) {
          if (inbox.failed) {
            noConnection = true;
            ondisconnected();
            _completer.complete(inbox.failed);
          } else {
            _conversations.clear();
            _conversations.addAll(inbox.conversations);

            String selectedChannel = null;
            if (conversation == null &&
                inbox.conversationId != null &&
                noDefaultLoad == false)
              selectedChannel = inbox.conversationId;
            else
              selectedChannel = conversation.id;
            selectChannel(Conversation(id: selectedChannel)).then((value) {
              _completer.complete(inbox.failed);
            });
          }
        });
      } else {
        print("Setting channel to ${conversation}");
        selectChannel(conversation).then((value) {
          _completer.complete(false);
        });
      }

      /*
      getCustomerHistory(
        conversationChannel: _conversationChannel,
        c: _customer,
        messages: _messages,
        rebuild: rebuild,
        setConversationChannel: setConversationChannel,
        setCustomer: setCustomer,
        socket: _socket,
        p: props,
      ).then((failed) {
        if (failed) {
          noConnection = true;
          ondisconnected();
          _completer.complete(failed);
        } else {
          _completer.complete(failed);
        }
      });
      */
    });

    /*
    if (props.customer != null &&
        props.customer.externalId != null &&
        (_customer == null || _customer.createdAt == null) &&
        _conversation == null) {
    
    }
    */

    return _completer.future;
  }

  void retry(Props props) {
    if (_socket.isConnected == false) {
      _connected = false;
      noConnection = true;
      _socket.close();
      _socket.dispose();
      ensureConnected(props);
    }

    /*
    fetch(props, _conversationId).then((failed) {
      if (!failed) {
        _socket.connect();
        noConnection = false;
        onconnected();
      }
    });
    */

    /*
    if (props.customer != null &&
        props.customer.externalId != null &&
        (_customer == null || _customer.createdAt == null) &&
        _conversation == null)
      getCustomerHistory(
        conversationChannel: _conversationChannel,
        c: _customer,
        messages: _messages,
        rebuild: rebuild,
        setConversationChannel: setConversationChannel,
        setCustomer: setCustomer,
        socket: _socket,
        p: props,
      ).then((failed) {
        if (!failed) {
          _socket.connect();
          noConnection = false;
          onconnected();
        }
      });*/
  }

  /*
  void _subscribeToSocket() {
    _socket.closeStream.listen((event) {
      _connected = false;
      noConnection = true;
      ondisconnected();
    });

    _socket.openStream.listen(
      (event) {
        if (noConnection && mounted) {
          rebuild(() {
            noConnection = false;
          }, animate: true);
        }
        return _connected = true;
      },
    );
  }
  */

  PapercupsMessage messageFromString(Props props) {
    return PapercupsMessage(
      body: props.greeting,
      sentAt: DateTime.now(),
      createdAt: DateTime.now(),
      accountId: props.accountId,
      user: User(
        fullName: props.companyName,
      ),
      userId: 0,
      id: "greeting",
    );
  }

  bool isDarkText(Props props, BuildContext context) {
    bool textBlack = false;
    if ((props.primaryColor != null &&
            props.primaryColor.computeLuminance() > 0.5) ||
        (props.primaryGradient != null &&
            props.primaryGradient.colors[0].computeLuminance() > 0.5) ||
        (props.primaryColor == null &&
            Theme.of(context).primaryColor.computeLuminance() > 0.5))
      textBlack = true;
    return textBlack;
  }

  void _shoutMessage(PapercupsMessage msg, PhoenixChannel channel) {
    assert(msg != null && msg.customer != null);
    var push = channel.push(
      "shout",
      {
        "body": msg.body,
        "customer_id": msg.customer.id,
        "sent_at": msg.createdAt.toIso8601String(),
      },
    );

    push.future.then((response) {
      _sending = false;
      rebuild(() {});
    });

    rebuild(() {});
  }

  void _sendMessage(
    //PapercupsCustomer cu,
    Props p,
    Function setCust,
    Conversation conv,
    //Function setConv,
    //Function setConvChannel,
    PhoenixChannel conversationChannel,
    PhoenixSocket socket,
    //bool sending,
    PapercupsMessage msg,
  ) {
    print("conversationChannel == .... ${conversationChannel}");
    if (conversationChannel == null) {
      // ensure the user exists by creating it if nessecary
      print("setCustomer.... ${_customer.id} ${_customer.externalId}");
      identify(p, create: true).then((customerDetails) {
        print(
            "setCustomer.... ${customerDetails.id} ${customerDetails.externalId}");
        msg.customer = customerDetails;
        getConversation(p, joins: true).then((conversationDetails) {
          rebuild(() {
            _conversation.messages.add(msg);
          }, stateMsg: true);

          _shoutMessage(msg, conversationDetails.channel);
        });
      });
    } else {
      rebuild(() {
        _conversation.messages.add(msg);
      }, stateMsg: true);

      msg.customer = _customer;
      _shoutMessage(msg, conversationChannel);
    }
  }

  void _sendMessageEx(
    Props p,
    PapercupsMessage msg,
  ) {
    _sendMessage(
        p, setCustomer, _conversation, _conversationChannel, _socket, msg);
  }
}

class _PaperCupsWidgetState2 extends State<PaperCupsWidgetB>
    with _PaperCupsMixin {
  ScrollController _controller = ScrollController();
  bool textBlack = false;

  @override
  void initState() {
    super.initStateA(widget.props);

    if (widget.dateLocale != "en-US") {
      initializeDateFormatting().then((_) {
        if (mounted) setState(() {});
      });
    }

    _stateMessageController.stream.listen((event) {
      _sendMessageEx(widget.props, event);
    });

    super.initState();
  }

  @override
  void dispose() {
    super.disposeA();
    if (_controller != null) _controller.dispose();
    super.dispose();
  }

  @override
  void onconnected() {
    if (widget.props.greeting != null) {
      _default = [messageFromString(widget.props)];
    } else {
      _default = [];
    }

    fetch(widget.props, _conversation).then((failed) {
      if (failed) {
        Alert.show(
          "There was an issue retrieving your details. Please try again!",
          context,
          backgroundColor: Theme.of(context).bottomAppBarColor,
          textStyle: Theme.of(context).textTheme.bodyText2,
          gravity: Alert.bottom,
          duration: Alert.lengthLong,
        );
      } else {
        if (mounted) setState(() {});
      }
    });

    if (mounted) setState(() {});
  }

  @override
  void ondisconnected() {
    if (mounted) setState(() {});
  }

  @override
  void onconversationloaded(String conversationId) {
    if (mounted) setState(() {});
  }

  @override
  void onconversationunloaded(String conversationId) {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    ensureConnected(widget.props);
    textBlack = isDarkText(widget.props, context);
    super.didChangeDependencies();
  }

  void openchat({String conversationId}) {
    if (conversationId == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => PaperCupsWidgetB(props: widget.props)),
      );
    } else {
      goto(widget.props, conversationId);
    }
  }

  void newchat() {
    goto(widget.props, null);
  }

  @override
  void setCustomer(PapercupsCustomer c, {rebuild = false}) {
    print("setCustomer.... ${c.id} ${c.externalId}");
    _customer = c;
    if (rebuild) setState(() {});
  }

  @override
  void setConversation(Conversation c) {
    print("setConversation.... ${c.id} ${c.messages.length}");
    _conversation = c;
    setState(() {});
  }

  @override
  void setConversationChannel(PhoenixChannel c) {
    _conversationChannel = c;
  }

  @override
  void rebuild(void Function() fn, {bool stateMsg = false, animate = false}) {
    _sending = stateMsg;
    if (mounted) setState(fn);
    if (animate &&
        mounted &&
        _conversation != null &&
        _conversation.messages != null &&
        _conversation.messages.isNotEmpty &&
        WidgetsBinding.instance != null &&
        _controller.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.position.maxScrollExtent != null)
          _controller.animateTo(
            _controller.position.maxScrollExtent,
            curve: Curves.easeIn,
            duration: Duration(milliseconds: 300),
          );
      });
    }
  }

  Widget conversationInbox(BuildContext context) {
    return SizedBox(
        height: 100,
        child: ListView.builder(
          itemCount: _conversations.length,
          itemBuilder: (context, index) {
            Conversation conversation =
                _conversations[_conversations.keys.elementAt(index)];

            String conversationId = conversation.id;
            String body = conversation.messages != null
                ? conversation.messages.isNotEmpty
                    ? conversation.messages[0].body
                    : ""
                : "";
            String sentAt = conversation.createdAt;
            return InkWell(
                child: Text('${body} ${sentAt}'),
                onTap: () {
                  openchat(conversationId: conversationId);
                });
          },
        ));
  }

  @override
  Widget build(BuildContext context) {
    initChannels(
      _connected,
      _socket,
      _channel,
      widget.props,
      _canJoinConversation,
      rebuild,
    );
    if (widget.props.primaryColor == null &&
        widget.props.primaryGradient == null)
      widget.props.primaryColor = Theme.of(context).primaryColor;
    return Container(
      color: Theme.of(context).canvasColor,
      child: noConnection
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 100,
                    color: Colors.grey,
                  ),
                  Text(
                    "No Connection",
                    style: Theme.of(context).textTheme.headline5.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  FlatButton.icon(
                    onPressed: () {
                      retry(widget.props);
                    },
                    icon: Icon(Icons.refresh_rounded),
                    label: Text("Retry"),
                    textColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(90),
                    ),
                  )
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Header(
                  props: widget.props,
                  closeAction: widget.closeAction,
                  textBlack: textBlack,
                ),
                // if (widget.props.showAgentAvailability)
                //   AgentAvailability(widget.props),

                FlatButton.icon(
                  onPressed: () {
                    openchat();
                  },
                  icon: Icon(Icons.refresh_rounded),
                  label: Text("Open chat"),
                  textColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(90),
                  ),
                ),

                FlatButton.icon(
                  onPressed: () {
                    newchat();
                  },
                  icon: Icon(Icons.refresh_rounded),
                  label: Text("New chat"),
                  textColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(90),
                  ),
                ),

                conversationInbox(context),

                Expanded(
                  child: ChatMessages(
                    widget.props,
                    _conversation != null ? _conversation.messages : [],
                    _controller,
                    _sending,
                    widget.dateLocale,
                    widget.timeagoLocale,
                    widget.sendingText,
                    widget.sentText,
                    textBlack,
                  ),
                ),
                if (!widget.floatingSendMessage) PoweredBy(),
                Container(
                  margin: widget.floatingSendMessage
                      ? EdgeInsets.only(
                          right: 15,
                          left: 15,
                        )
                      : null,
                  decoration: widget.floatingSendMessage
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                              BoxShadow(
                                blurRadius: 10,
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.grey.withOpacity(0.4)
                                    : Colors.black.withOpacity(0.8),
                              )
                            ])
                      : BoxDecoration(),
                  clipBehavior:
                      widget.floatingSendMessage ? Clip.antiAlias : Clip.none,
                  child: (widget.props.requireEmailUpfront &&
                          (_customer == null || _customer.email == null))
                      ? RequireEmailUpfront(setCustomer, widget.props,
                          textBlack, !widget.floatingSendMessage)
                      : SendMessage(
                          props: widget.props,
                          controller: _stateMessageController,
                          //customer: _customer,
                          //setCustomer: setCustomer,
                          //setConversation: setConversation,
                          //conversationChannel: _conversationChannel,
                          //setConversationChannel: setConversationChannel,
                          //conversation: _conversation,
                          //setState: rebuild,
                          //messages: _messages,
                          //socket: _socket,
                          sending: _sending,
                          textBalck: textBlack,
                          showDivider: !widget.floatingSendMessage,
                        ),
                ),
                if (widget.floatingSendMessage)
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: PoweredBy(),
                  ),
              ],
            ),
    );
  }
}
