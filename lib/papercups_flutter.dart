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

class ConversationPair {
  final PapercupsCustomer customer;
  final Conversation conversation;
  final PhoenixChannel channel;
  ConversationPair({
    this.customer,
    this.conversation,
    this.channel,
  });
}

class Update {
  Future<Conversation> future;
}

typedef void RebuildFunction(void Function() fn, {bool stateMsg, bool animate});
typedef void SetConversationFunction(Conversation c);

class PaperCupsController {
  StreamController<PapercupsMessage> _stateMessageController =
      StreamController<PapercupsMessage>();
  StreamController _stateStreamController = StreamController.broadcast();
  // ignore: unused_field
  Stream<PaperCupsConnectedEvent> _openStream;
  // ignore: unused_field
  Stream<PaperCupsDisconnectedEvent> _closeStream;
  // ignore: unused_field
  Stream<PaperCupsConversationMessageStatusEvent> _sendingStatusChanged;
  // internal main phoenix socket that manages various subchannels (basically websockets)
  PhoenixSocket _socket;
  // internal phoenix channel listenng to chatter of an account
  PhoenixChannel _channel;
  // internal phoenix channels listening to chatter of a conversation
  Map<String, PhoenixChannel> _conversationChannel = {};
  // internal conversations that are monitored on the same socket
  Map<String, Conversation> _conversations = {};
  // internal the current identified customer
  PapercupsCustomer _customer;
  // internal rebuild function
  RebuildFunction rebuild;
  //SetConversationFunction setConversation;

  //bool _connected = false;
  //List<PapercupsMessage> _messages = [];
  //bool _canJoinConversation = false;
  //String _conversationId;
  //bool noConnection = false;

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
    _sendingStatusChanged = _stateStreamController.stream
        .where((event) => event is PaperCupsConversationMessageStatusEvent)
        .cast<PaperCupsConversationMessageStatusEvent>();
  }

  Future<PhoenixSocket> connect(Props props,
      {bool retry, PhoenixSocketOptions options}) {
    print("connecting...");
    if (_socket == null) {
      try {
        _socket = PhoenixSocket("wss://" + props.baseUrl + '/socket/websocket',
            socketOptions: options);
      } catch (e) {
        print("connecting had an exception... ${e}");
        _socket = null;
        return Future<PhoenixSocket>.value(null);
      }

      _socket.closeStream.listen((event) {
        print("stream closed....");
        _stateStreamController.add(PaperCupsDisconnectedEvent());
      });

      _socket.openStream.listen(
        (event) {
          //var completer = Completer<bool>();
          print("stream opened....");
          _channel = initChannelsEx(_socket, props, null);
          _stateStreamController.add(PaperCupsConnectedEvent());
        },
      );

      _socket.errorStream.listen((event) {
        print("stream errored....");
        _stateStreamController.addError(event);
      });

      /*
      .catchError((error) {
        _stateStreamController.addError(error);
      });
      */
      print("connecting....");
      _socket.connect();
      print("connecting done....");

      return Future<PhoenixSocket>.value(_socket);
    } else {
      return Future<PhoenixSocket>.value(_socket);
    }
  }

  //void onconnected();
  //void ondisconnected();
  //void onconversationloaded(String conversationId);
  //void onconversationunloaded(String conversationId);

  void setConversationChannel(String convId, PhoenixChannel c) {
    if (c == null) {
      if (_conversationChannel.containsKey(convId)) {
        PhoenixChannel previous = _conversationChannel[convId];
        if (previous.state != PhoenixChannelState.closed) {
          previous.close();
        }
        _conversationChannel.remove(convId);
      }
    } else {
      _conversationChannel[convId] = c;
    }
  }

  void disposeA() {
    if (_channel != null) _channel.close();
    if (_socket != null) _socket.dispose();
    if (_stateMessageController != null) _stateMessageController.close();
    if (_conversationChannel.isNotEmpty) {
      _conversationChannel.forEach((key, value) {
        value.close();
      });
      _conversationChannel.clear();
    }
  }

  Future<PhoenixChannel> join(Conversation conversation) async {
    assert(conversation != null);

    var statusEvents = StreamController<PaperCupsConversationEvent>();
    var controller = StreamController<List<PapercupsMessage>>();
    controller.stream.listen((messages) {
      rebuild(() {
        conversation.messages.addAll(messages);
      }, animate: true);
    });

    statusEvents.stream.listen((event) {
      //Set the conversation channel
      if (event is PaperCupsConversationConnectedEvent) {
        setConversationChannel(conversation.id, event.channel);
      }
      // Unset the conversation channel
      else if (event is PaperCupsConversationDisconnectedEvent) {
        setConversationChannel(conversation.id, null);
      }
    });

    var conv = joinConversationAndListenEx(
      convId: conversation.id,
      eventsController: statusEvents,
      controller: controller,
      socket: _socket,
    );

    return conv;
  }

  void goto(Props props, String conversationId, PaperCupsViewController view) {
    if (_conversations.containsKey(conversationId)) {
      fetch(props, _conversations[conversationId],
          noDefaultLoad: true, view: view);
    } else {
      //Create a new messages list so the DateTime is properly set.
      List<PapercupsMessage> messages = [messageFromString(props)];
      fetch(props, Conversation(messages: messages),
          noDefaultLoad: true, view: view);
    }
  }

  void setCustomer(PapercupsCustomer c, {rebuild = false}) {
    print("setCustomer.... ${c.id} ${c.externalId}");
    _customer = c;
    _stateStreamController.add(PaperCupsCustomerIdentifiedEvent(c, rebuild));
  }

  /*
  Future<bool> selectChannel(
      Conversation prevConversation, Conversation conversation) async {
    String previousConversationId =
        prevConversation != null ? prevConversation.id : null;
    String newConversationId = conversation != null ? conversation.id : null;
    print("selecting conversation id: ${newConversationId}");
    //_messages.clear();
    if (_conversations.containsKey(newConversationId)) {
      //_messages.addAll(_conversations[conversationId].messages);
      setConversationChannel(previousConversationId, null);
      _stateStreamController.add(PaperCupsConversationUnloadEvent(
          conversationId: previousConversationId));

      //onconversationunloaded(previousConversationId);
      //_conversationId = conversationId;
      if (newConversationId == null) {
        print("reset messages: ${newConversationId}");
        setConversation(null);
        setConversationChannel(newConversationId, null);
      } else {
        print("join conversation id: ${newConversationId}");
        setConversation(_conversations[newConversationId]);
        join(_conversations[newConversationId]);
      }

      _stateStreamController.add(
          PaperCupsConversationLoadEvent(conversationId: newConversationId));
      //onconversationloaded(newConversationId);
      return true;
    } else {
      print("reset messages: ${newConversationId}");
      setConversationChannel(previousConversationId, null);
      _stateStreamController.add(PaperCupsConversationUnloadEvent(
          conversationId: previousConversationId));
      //onconversationunloaded(previousConversationId);
      //_conversationId = conversationId;
      setConversation(conversation);
      setConversationChannel(newConversationId, null);
      //onconversationloaded(newConversationId);
      _stateStreamController.add(
          PaperCupsConversationLoadEvent(conversationId: newConversationId));
      return false;
    }
  }
  */

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

  Future<ConversationPair> getConversation(Props props,
      {bool joins,
      Conversation conversation,
      Future<PapercupsCustomer> customer,
      PaperCupsViewController view}) async {
    if (conversation != null && conversation.id != null) {
      PapercupsCustomer identifiedCustomer = await customer;
      PhoenixChannel channel = _conversationChannel[conversation.id];
      if (channel != null) {
        return Future<ConversationPair>.value(ConversationPair(
            conversation: conversation,
            channel: channel,
            customer: identifiedCustomer));
      } else {
        var completer = Completer<ConversationPair>();
        join(conversation).then((conv) {
          completer.complete(ConversationPair(
              conversation: conversation,
              channel: conv,
              customer: identifiedCustomer));
        }).catchError((error) {
          _stateStreamController.addError(error);
          completer.completeError(error);
        });

        return completer.future;
      }
    } else {
      var completer = Completer<ConversationPair>();
      customer.then((identifiedCustomer) {
        var customerId = identifiedCustomer.id;
        createConversation(props, conversation, _customer, (Conversation a) {
          view._conversation = a;
          _stateStreamController
              .add(PaperCupsConversationNavigatedEvent(a, false));
        }).then((conversationDetails) {
          // Check if the conversation fullfills the basic requirements
          assert(conversationDetails.customerId == customerId &&
              conversationDetails.id != null);
          _conversations[conversationDetails.id] = conversationDetails;
          //_conversationId = conversationDetails.id;
          join(conversationDetails).then((conv) {
            completer.complete(ConversationPair(
                conversation: conversationDetails,
                channel: conv,
                customer: identifiedCustomer));
          }).catchError((error) {
            _stateStreamController.addError(error);
            completer.completeError(error);
          });
        }).catchError((error) {
          _stateStreamController.addError(error);
          completer.completeError(error);
        });
      });
      return completer.future;
    }
  }

  Future<bool> fetch(Props props, Conversation conversation,
      {bool noDefaultLoad = false, PaperCupsViewController view}) {
    Completer<bool> _completer = Completer<bool>();
    print("fetch to ${conversation}");
    identify(props).then((customer) {
      if (conversation == null || conversation.id != null) {
        print("Updating customer history");
        getCustomerHistoryEx(c: _customer, p: props, setCustomer: setCustomer)
            .then((Inbox inbox) {
          if (inbox.failed) {
            //ondisconnected();
            _stateStreamController.add(PaperCupsDisconnectedEvent());
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
            view
                ._selectChannel(conversation, Conversation(id: selectedChannel))
                .then((value) {
              _completer.complete(inbox.failed);
            });
          }
        });
      } else {
        print("Setting channel to ${conversation}");
        view._selectChannel(conversation, conversation).then((value) {
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
    }).catchError((error) {
      _stateMessageController.addError(error);
    });

    return _completer.future;
  }

  Future<PhoenixSocket> retry(Props props, {PhoenixSocketOptions options}) {
    PhoenixSocket socket = _socket;
    if (socket != null && socket.isConnected == false) {
      _socket = null;
      _conversationChannel.clear();
      socket.close();
      socket.dispose();
      return connect(props, retry: true, options: options);
    } else {
      return Future<PhoenixSocket>.value(socket);
    }
  }

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

  void _shoutMessage(Props props, Conversation conv, PapercupsMessage msg,
      Future<ConversationPair> channel) {
    rebuild(() {
      conv.messages.add(msg);
    });

    channel.then((value) {
      msg.customer = value.customer;
      print("setCustomer.... ${msg.customer.id} ${msg.customer.externalId}");
      assert(msg != null && msg.customer != null);
      _stateStreamController.add(PaperCupsConversationMessageSending(
          channel: value.channel, conversationId: msg.conversationId));

      var push = value.channel.push(
        "shout",
        {
          "body": msg.body,
          "customer_id": msg.customer.id,
          "sent_at": msg.createdAt.toIso8601String(),
        },
      );
      push.future.then((response) {
        _stateStreamController.add(PaperCupsConversationMessageDone(
            channel: value.channel, conversationId: msg.conversationId));
        if (response.isError || response.isTimeout) {
          msg.sentAt = null;
        } else {
          updateUserMetadataEx(props, msg.customer, msg.customer.id);
        }
      }, onError: (error) {
        _stateStreamController.add(PaperCupsConversationMessageDone(
            channel: value.channel, conversationId: msg.conversationId));
      });
    });
  }

  void _sendMessage(
    Props p,
    Conversation conv,
    PapercupsMessage msg,
    PaperCupsViewController view,
  ) async {
    PhoenixChannel conversationChannel =
        _conversationChannel.containsKey(conv.id)
            ? _conversationChannel[conv.id]
            : null;
    print("conversationChannel == .... ${conversationChannel}");
    if (conversationChannel == null) {
      _shoutMessage(
          p,
          conv,
          msg,
          // create or get the conversation
          getConversation(p,
              joins: true,
              conversation: conv,
              view: view,
              // identify the customer
              customer: identify(p, create: true)));
    } else {
      _shoutMessage(
          p,
          conv,
          msg,
          // we already have a cusomer, channel, conversation
          Future<ConversationPair>.value(ConversationPair(
              channel: _channel, customer: _customer, conversation: conv)));
    }
  }
}

class PaperCupsViewController {
  // internal controller associated for this view
  final PaperCupsController _controller;
  // intnernal conversation object associated with this view
  Conversation _conversation;
  Conversation get conversation {
    return _conversation;
  }

  PaperCupsController get controller {
    return _controller;
  }

  Future<bool> _selectChannel(
      Conversation prevConversation, Conversation conversation) async {
    String previousConversationId =
        prevConversation != null ? prevConversation.id : null;
    String newConversationId = conversation != null ? conversation.id : null;
    print("selecting conversation id: ${newConversationId}");
    //_messages.clear();
    if (_controller._conversations.containsKey(newConversationId)) {
      //_messages.addAll(_conversations[conversationId].messages);
      _controller.setConversationChannel(previousConversationId, null);
      _controller._stateStreamController.add(PaperCupsConversationUnloadEvent(
          conversationId: previousConversationId));

      //onconversationunloaded(previousConversationId);
      //_conversationId = conversationId;
      if (newConversationId == null) {
        print("reset messages: ${newConversationId}");
        _conversation = null;
        _controller.setConversationChannel(newConversationId, null);
      } else {
        print("join conversation id: ${newConversationId}");
        _conversation = _controller._conversations[newConversationId];
        _controller.join(_controller._conversations[newConversationId]);
      }

      _controller._stateStreamController.add(
          PaperCupsConversationLoadEvent(conversationId: newConversationId));
      _controller._stateStreamController
          .add(PaperCupsConversationNavigatedEvent(_conversation, false));
      //onconversationloaded(newConversationId);
      return true;
    } else {
      print("reset messages: ${newConversationId}");
      _controller.setConversationChannel(previousConversationId, null);
      _controller._stateStreamController.add(PaperCupsConversationUnloadEvent(
          conversationId: previousConversationId));
      //onconversationunloaded(previousConversationId);
      //_conversationId = conversationId;
      _conversation = conversation;
      _controller.setConversationChannel(newConversationId, null);
      //onconversationloaded(newConversationId);
      _controller._stateStreamController.add(
          PaperCupsConversationLoadEvent(conversationId: newConversationId));
      _controller._stateStreamController
          .add(PaperCupsConversationNavigatedEvent(_conversation, false));
      return false;
    }
  }

  Future<bool> navigate(Conversation conversation) {
    return _selectChannel(_conversation, Conversation(id: conversation.id));
  }

  PaperCupsViewController(this._controller);
}

abstract class _PaperCupsMixin {
  PaperCupsController messagingController;
  PaperCupsViewController viewController;
  void rebuild(void Function() fn, {bool stateMsg = false, animate = false});
  void setCustomer(PapercupsCustomer c, {rebuild = false});
  void initStateA(Props props) {
    messagingController = PaperCupsController();
    messagingController.rebuild = rebuild;
    viewController = PaperCupsViewController(messagingController);
    messagingController.initStateA(props);
  }

  void disposeA() {
    messagingController.disposeA();
  }
}

abstract class _PaperCupsThemeMixin {
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
}

class _PaperCupsWidgetState2 extends State<PaperCupsWidgetB>
    with _PaperCupsMixin, _PaperCupsThemeMixin {
  ScrollController _controller = ScrollController();
  // internal the current active conversation

  bool textBlack = false;
  bool _sending = false;
  bool noConnection = true;

  @override
  void initState() {
    super.initStateA(widget.props);

    if (widget.dateLocale != "en-US") {
      initializeDateFormatting().then((_) {
        if (mounted) setState(() {});
      });
    }

    messagingController._stateMessageController.stream.listen((event) {
      messagingController._sendMessage(
          widget.props, viewController.conversation, event, viewController);
    });

    messagingController._sendingStatusChanged.listen((event) {
      if (event is PaperCupsConversationMessageSendEvent) {
        setState(() {
          _sending = true;
        });
      } else if (event is PaperCupsConversationMessageDone) {
        setState(() {
          _sending = false;
        });
      }
    });

    messagingController._stateStreamController.stream
        .where((event) => event is PaperCupsConnectionEvent)
        .cast<PaperCupsConnectionEvent>()
        .listen((event) {
      if (event is PaperCupsConnectedEvent) {
        onconnected();
      } else if (event is PaperCupsDisconnectedEvent) {
        ondisconnected();
      }
    });

    messagingController._stateStreamController.stream
        .where((event) => event is PaperCupsConversationEvent)
        .cast<PaperCupsConversationEvent>()
        .listen((event) {
      if (event is PaperCupsConversationLoadEvent) {
        onconversationloaded(event.conversationId);
      } else if (event is PaperCupsConversationUnloadEvent) {
        onconversationunloaded(event.conversationId);
      }
    });

    messagingController._stateStreamController.stream
        .where((event) => event is PaperCupsCustomerIdentifiedEvent)
        .cast<PaperCupsCustomerIdentifiedEvent>()
        .listen((event) {
      setCustomer(event.customer, rebuild: event.rebuild);
    });

    messagingController._stateStreamController.stream
        .where((event) => event is PaperCupsConversationNavigatedEvent)
        .cast<PaperCupsConversationNavigatedEvent>()
        .listen((event) {
      setConversation(event.conversation);
    });

    messagingController._stateStreamController.stream.handleError((error) {
      String _desc = error.toString();
      Alert.show(
        _desc,
        context,
        backgroundColor: Theme.of(context).bottomAppBarColor,
        textStyle: Theme.of(context).textTheme.bodyText2,
        gravity: Alert.bottom,
        duration: Alert.lengthLong,
      );
    });

    super.initState();
  }

  @override
  void dispose() {
    super.disposeA();
    if (_controller != null) _controller.dispose();
    super.dispose();
  }

  //@override
  void onconnected() {
    if (noConnection) {
      noConnection = false;
      rebuild(() {}, animate: true);
    }

    messagingController
        .fetch(widget.props, viewController.conversation, view: viewController)
        .then((failed) {
      if (failed) {
        messagingController._stateStreamController.addError(
            "There was an issue retrieving your details. Please try again!");
      } else {
        if (mounted) setState(() {});
      }
    });

    if (mounted) setState(() {});
  }

  //@override
  void ondisconnected() {
    noConnection = true;
    if (mounted) setState(() {});
  }

  //@override
  void onconversationloaded(String conversationId) {
    if (mounted) setState(() {});
  }

  //@override
  void onconversationunloaded(String conversationId) {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    messagingController.connect(widget.props);
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
      messagingController.goto(widget.props, conversationId, viewController);
    }
  }

  void newchat() {
    messagingController.goto(widget.props, null, viewController);
  }

  void setCustomer(PapercupsCustomer c, {rebuild = false}) {
    print("setCustomer.... ${c.id} ${c.externalId}");
    if (rebuild && mounted) setState(() {});
  }

  void setConversation(Conversation c) {
    print("setConversation.... ${c.id} ${c.messages.length}");
    //viewController.navigate(c);
    if (mounted) setState(() {});
  }

  //@override
  void rebuild(void Function() fn, {bool stateMsg = false, animate = false}) {
    _sending = stateMsg;
    if (mounted) setState(fn);
    Conversation conversation = viewController.conversation;

    if (animate &&
        mounted &&
        conversation != null &&
        conversation.messages != null &&
        conversation.messages.isNotEmpty &&
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
          itemCount: messagingController._conversations.length,
          itemBuilder: (context, index) {
            Conversation conversation = messagingController._conversations[
                messagingController._conversations.keys.elementAt(index)];

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
                      messagingController.retry(widget.props);
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
                    viewController.conversation != null
                        ? viewController.conversation.messages
                        : [],
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
                          (messagingController._customer == null ||
                              messagingController._customer.email == null))
                      ? RequireEmailUpfront(setCustomer, widget.props,
                          textBlack, !widget.floatingSendMessage)
                      : SendMessage(
                          props: widget.props,
                          controller:
                              messagingController._stateMessageController,
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
