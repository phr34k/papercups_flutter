library papercups_flutter;

// Imports.
import 'package:flutter/material.dart';
import 'utils/utils.dart';
import 'widgets/widgets.dart';
import 'package:phoenix_socket/phoenix_socket.dart';
import 'models/models.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'dart:developer' as developer;

// Exports.
export 'models/classes.dart';
export 'package:timeago/timeago.dart';

void log(String error, {int level, String name}) {
  developer.log(error, level: level, name: name);
  print(error);
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
  Conversation oldConversation;
  Conversation newConversation;
  Update(
    this.oldConversation,
    this.newConversation,
  );
}

class PaperCupsController {
  StreamController stateStreamController = StreamController.broadcast();
  // ignore: unused_field
  Stream<PaperCupsConnectedEvent> openStream;
  // ignore: unused_field
  Stream<PaperCupsDisconnectedEvent> closeStream;
  // ignore: unused_field
  Stream<PaperCupsConversationMessageStatusEvent> sendingStatusChanged;
  // internal main phoenix socket that manages various subchannels (basically websockets)
  PhoenixSocket _socket;
  // internal phoenix channel listenng to chatter of an account
  PhoenixChannel _channel;
  // internal phoenix channels listening to chatter of a conversation
  Map<String, PhoenixChannel> _conversationChannel = {};
  // internal conversations that are monitored on the same socket
  Map<String, Conversation> conversations = {};
  // internal the current identified customer
  PapercupsCustomer _customer;
  // internal rebuild function
  //RebuildFunction rebuild;
  //SetConversationFunction setConversation;

  //bool _connected = false;
  //List<PapercupsMessage> _messages = [];
  //bool _canJoinConversation = false;
  //String _conversationId;
  //bool noConnection = false;

  PapercupsCustomer get customer {
    return _customer;
  }

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

    openStream = stateStreamController.stream
        .where((event) => event is PaperCupsConnectedEvent)
        .cast<PaperCupsConnectedEvent>();
    closeStream = stateStreamController.stream
        .where((event) => event is PaperCupsDisconnectedEvent)
        .cast<PaperCupsDisconnectedEvent>();
    sendingStatusChanged = stateStreamController.stream
        .where((event) => event is PaperCupsConversationMessageStatusEvent)
        .cast<PaperCupsConversationMessageStatusEvent>();
  }

  Future<PhoenixSocket> connect(Props props,
      {bool retry, PhoenixSocketOptions options}) {
    log("connecting...", level: 0, name: 'papercups.controller');
    if (_socket == null) {
      try {
        _socket = PhoenixSocket("wss://" + props.baseUrl + '/socket/websocket',
            socketOptions: options);
      } catch (e) {
        log("connecting had an exception... ${e}",
            level: 0, name: 'papercups.controller');
        _socket = null;
        return Future<PhoenixSocket>.value(null);
      }

      _socket.closeStream.listen((event) {
        log("stream closed....", level: 0, name: 'papercups.controller');
        stateStreamController.add(PaperCupsDisconnectedEvent());
      });

      _socket.openStream.listen(
        (event) {
          //var completer = Completer<bool>();
          log("stream opened....", level: 0, name: 'papercups.controller');
          _channel = initChannelsEx(_socket, props, null);
          stateStreamController.add(PaperCupsConnectedEvent());
        },
      );

      _socket.errorStream.listen((event) {
        log("stream errored....", level: 0, name: 'papercups.controller');
        stateStreamController.addError(event);
      });

      /*
      .catchError((error) {
        stateStreamController.addError(error);
      });
      */
      log("connecting....", level: 0, name: 'papercups.controller');
      _socket.connect();
      log("connecting done....", level: 0, name: 'papercups.controller');

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
      conversation.messages.addAll(messages);
      stateStreamController.add(PaperCupsConversationMessageReceivedEvent(
        messages: messages,
      ));
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

  void setCustomer(PapercupsCustomer c, {rebuild = false}) {
    log("setCustomer.... ${c.id} ${c.externalId}",
        level: 0, name: 'papercups.controller');
    _customer = c;
    stateStreamController.add(PaperCupsCustomerIdentifiedEvent(c, rebuild));
  }

  //Identify the customer
  Future<PapercupsCustomer> identify(Props props, {bool create = false}) {
    if (props.customer != null &&
        props.customer.externalId != null &&
        (_customer == null || _customer.createdAt == null)) {
      log("identity getCustomerDetailsFromMetadata",
          level: 0, name: 'papercups.controller');
      return getCustomerDetailsFromMetadata(props, _customer, setCustomer);
    } else if (_customer == null) {
      if (create == true) {
        log("identity getCustomerDetails",
            level: 0, name: 'papercups.controller');
        return getCustomerDetails(props, _customer, setCustomer);
      } else {
        log("identity no customer, and wasn't created",
            level: 0, name: 'papercups.controller');
        return Future<PapercupsCustomer>.value(_customer);
      }
    } else {
      log("identity existing customer", level: 0, name: 'papercups.controller');
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
          stateStreamController.addError(error);
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
          stateStreamController
              .add(PaperCupsConversationNavigatedEvent(a, false));
        }).then((conversationDetails) {
          // Check if the conversation fullfills the basic requirements
          assert(conversationDetails.customerId == customerId &&
              conversationDetails.id != null);
          conversations[conversationDetails.id] = conversationDetails;
          //_conversationId = conversationDetails.id;
          join(conversationDetails).then((conv) {
            completer.complete(ConversationPair(
                conversation: conversationDetails,
                channel: conv,
                customer: identifiedCustomer));
          }).catchError((error) {
            stateStreamController.addError(error);
            completer.completeError(error);
          });
        }).catchError((error) {
          stateStreamController.addError(error);
          completer.completeError(error);
        });
      });
      return completer.future;
    }
  }

  Future<Update> fetch(Props props, Conversation conversation,
      {bool noDefaultLoad = false}) {
    Completer<Update> _completer = Completer<Update>();
    log("fetch to ${conversation}", level: 0, name: 'papercups.controller');
    identify(props).then((customer) {
      if (conversation == null || conversation.id != null) {
        log("Updating customer history",
            level: 0, name: 'papercups.controller');
        getCustomerHistoryEx(c: _customer, p: props, setCustomer: setCustomer)
            .then((Inbox inbox) {
          if (inbox.failed) {
            //ondisconnected();
            stateStreamController.add(PaperCupsDisconnectedEvent());
            _completer
                .completeError("An error occured while getting the inbox");
          } else {
            conversations.clear();
            if (inbox.conversations != null)
              conversations.addAll(inbox.conversations);

            String selectedChannel = null;
            if (conversation == null &&
                inbox.conversationId != null &&
                noDefaultLoad == false)
              selectedChannel = inbox.conversationId;
            else
              selectedChannel = conversation != null ? conversation.id : null;
            _completer.complete(
                Update(conversation, Conversation(id: selectedChannel)));
          }
        });
      } else {
        log("Setting channel to ${conversation}",
            level: 0, name: 'papercups.controller');
        _completer.complete(Update(conversation, conversation));
      }
    }).catchError((error) {
      stateStreamController.addError(error);
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
    log("say message, add to conversation",
        level: 0, name: 'papercups.controller');
    conv.messages.add(msg);
    stateStreamController.add(PaperCupsConversationMessageSendEvent(
      messages: [msg],
    ));

    if (_socket != null && _socket.isConnected) {
      channel.then((value) {
        msg.customer = value.customer;
        assert(msg != null && msg.customer != null);
        log("setCustomer.... ${msg.customer.id} ${msg.customer.externalId}",
            level: 0, name: 'papercups.controller');
        stateStreamController.add(PaperCupsConversationMessageSending(
            channel: value.channel, conversationId: msg.conversationId));

        if (value.channel == null) {
          log("couldn't create a realtime connection to channel",
              level: 0, name: 'papercups.controller');
          stateStreamController.addError("No connection to channel");
        } else {
          var push = value.channel.push(
            "shout",
            {
              "body": msg.body,
              "customer_id": msg.customer.id,
              "sent_at": msg.createdAt.toIso8601String(),
            },
          );
          push.future.then((response) {
            stateStreamController.add(PaperCupsConversationMessageDone(
                channel: value.channel, conversationId: msg.conversationId));
            if (response.isError || response.isTimeout) {
              msg.sentAt = null;
            } else {
              updateUserMetadataEx(props, msg.customer, msg.customer.id);
            }
          }, onError: (error) {
            stateStreamController.add(PaperCupsConversationMessageDone(
                channel: value.channel, conversationId: msg.conversationId));
          });
        }
      }, onError: (error) {
        stateStreamController.addError(error);
      });
    } else {
      stateStreamController.addError("Need to be connected first");
    }
  }

  void say(
    Props p,
    Conversation conv,
    PapercupsMessage msg,
    PaperCupsViewController view,
  ) async {
    if (_socket == null || _socket.isConnected == false) {
      stateStreamController.addError("Not connected");
      return;
    }

    log('conversationChannel...');
    PhoenixChannel conversationChannel =
        _conversationChannel.containsKey(conv.id)
            ? _conversationChannel[conv.id]
            : null;
    log("conversationChannel == .... ${conversationChannel}",
        level: 0, name: 'papercups.controller');
    _shoutMessage(
        p,
        conv,
        msg,
        conversationChannel == null
            ?
            // create or get the conversation
            getConversation(p,
                joins: true,
                conversation: conv,
                view: view,
                // find the custerom, since we don't have a channel, likely we don't have customer yet either
                customer: identify(p, create: true))
            // we already have all three components (channel, conversation, customer)
            : Future<ConversationPair>.value(ConversationPair(
                channel: conversationChannel,
                customer: _customer,
                conversation: conv)));
  }
}

class PaperCupsViewController {
  StreamController<PapercupsMessage> stateMessageController =
      StreamController<PapercupsMessage>();
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

  void disposeA() {
    if (stateMessageController != null) stateMessageController.close();
  }

  Future<bool> selectChannel(
      Conversation prevConversation, Conversation conversation) async {
    String previousConversationId =
        prevConversation != null ? prevConversation.id : null;
    String newConversationId = conversation != null ? conversation.id : null;
    log("selecting conversation id: ${newConversationId}",
        level: 0, name: 'papercups.controller');
    //_messages.clear();
    if (_controller.conversations.containsKey(newConversationId)) {
      //_messages.addAll(conversations[conversationId].messages);
      _controller.setConversationChannel(previousConversationId, null);
      _controller.stateStreamController.add(PaperCupsConversationUnloadEvent(
          conversationId: previousConversationId));

      //onconversationunloaded(previousConversationId);
      //_conversationId = conversationId;
      if (newConversationId == null) {
        log("reset messages: ${newConversationId}",
            level: 0, name: 'papercups.controller');
        _conversation = null;
        _controller.setConversationChannel(newConversationId, null);
      } else {
        log("join conversation id: ${newConversationId}",
            level: 0, name: 'papercups.controller');
        _conversation = _controller.conversations[newConversationId];
        _controller.join(_controller.conversations[newConversationId]);
      }

      _controller.stateStreamController.add(
          PaperCupsConversationLoadEvent(conversationId: newConversationId));
      _controller.stateStreamController
          .add(PaperCupsConversationNavigatedEvent(_conversation, false));
      //onconversationloaded(newConversationId);
      return true;
    } else {
      log("reset messages: ${newConversationId}",
          level: 0, name: 'papercups.controller');
      _controller.setConversationChannel(previousConversationId, null);
      _controller.stateStreamController.add(PaperCupsConversationUnloadEvent(
          conversationId: previousConversationId));
      //onconversationunloaded(previousConversationId);
      //_conversationId = conversationId;
      _conversation = conversation;
      _controller.setConversationChannel(newConversationId, null);
      //onconversationloaded(newConversationId);
      _controller.stateStreamController.add(
          PaperCupsConversationLoadEvent(conversationId: newConversationId));
      _controller.stateStreamController
          .add(PaperCupsConversationNavigatedEvent(_conversation, false));
      return false;
    }
  }

  void navigate(Props props, String conversationId) {
    if (_controller.conversations.containsKey(conversationId)) {
      _controller
          .fetch(props, _controller.conversations[conversationId],
              noDefaultLoad: true)
          .then((update) {
        selectChannel(update.oldConversation, update.newConversation);
      });
    } else {
      //Create a new messages list so the DateTime is properly set.
      List<PapercupsMessage> messages = [_controller.messageFromString(props)];
      _controller
          .fetch(props, Conversation(messages: messages), noDefaultLoad: true)
          .then((update) {
        selectChannel(update.oldConversation, update.newConversation);
      });
    }
  }

  PaperCupsViewController(this._controller);
}

mixin PaperCupsMixin {
  PaperCupsController messagingController;
  PaperCupsViewController viewController;

  void initStateA(Props props) {
    messagingController = PaperCupsController();
    viewController = PaperCupsViewController(messagingController);
    messagingController.initStateA(props);
  }

  void disposeA() {
    viewController.disposeA();
    messagingController.disposeA();
  }
}

mixin PaperCupsThemeMixin {
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

enum PaperCupsConnectionState {
  none,
  connected,
  disconnected,
}

class _PaperCupsWidgetState2 extends State<PaperCupsWidgetB>
    with PaperCupsMixin, PaperCupsThemeMixin {
  ScrollController _controller = ScrollController();
  bool textBlack = false;
  bool _sending = false;
  PaperCupsConnectionState _connectionState = PaperCupsConnectionState.none;

  @override
  void initState() {
    super.initStateA(widget.props);

    if (widget.dateLocale != "en-US") {
      initializeDateFormatting().then((_) {
        if (mounted) setState(() {});
      });
    }

    viewController.stateMessageController.stream.listen((event) {
      messagingController.say(
          widget.props, viewController.conversation, event, viewController);
    });

    messagingController.sendingStatusChanged.listen((event) {
      if (event is PaperCupsConversationMessageSending) {
        _sending = true;
        if (mounted) setState(() {});
      } else if (event is PaperCupsConversationMessageDone) {
        _sending = false;
        if (mounted) setState(() {});
      }
    });

    messagingController.stateStreamController.stream
        .where((event) => event is PaperCupsConnectionEvent)
        .cast<PaperCupsConnectionEvent>()
        .listen((event) {
      if (event is PaperCupsConnectedEvent) {
        onconnected();
      } else if (event is PaperCupsDisconnectedEvent) {
        ondisconnected();
      }
    });

    messagingController.stateStreamController.stream
        .where((event) => event is PaperCupsConversationEvent)
        .cast<PaperCupsConversationEvent>()
        .listen((event) {
      if (event is PaperCupsConversationMessageSendEvent) {
        rebuild(() {}, animate: true);
      } else if (event is PaperCupsConversationMessageReceivedEvent) {
        rebuild(() {});
      } else if (event is PaperCupsConversationLoadEvent) {
        onconversationloaded(event.conversationId);
      } else if (event is PaperCupsConversationUnloadEvent) {
        onconversationunloaded(event.conversationId);
      }
    });

    messagingController.stateStreamController.stream
        .where((event) => event is PaperCupsCustomerIdentifiedEvent)
        .cast<PaperCupsCustomerIdentifiedEvent>()
        .listen((event) {
      setCustomer(event.customer, rebuild: event.rebuild);
    });

    messagingController.stateStreamController.stream
        .where((event) => event is PaperCupsConversationNavigatedEvent)
        .cast<PaperCupsConversationNavigatedEvent>()
        .listen((event) {
      setConversation(event.conversation);
    });

    messagingController.stateStreamController.stream.handleError((error) {
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
    bool wasDisconnected =
        _connectionState == PaperCupsConnectionState.disconnected;
    _connectionState = PaperCupsConnectionState.connected;
    messagingController.fetch(widget.props, viewController.conversation).then(
        (update) {
      viewController.selectChannel(
          update.oldConversation, update.newConversation);
      if (mounted) setState(() {});
    }, onError: (error) {
      messagingController.stateStreamController.addError(
          "There was an issue retrieving your details. Please try again! ${error}");
    });

    rebuild(() {}, animate: wasDisconnected);
  }

  //@override
  void ondisconnected() {
    _connectionState = PaperCupsConnectionState.disconnected;
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
      viewController.navigate(widget.props, conversationId);
    }
  }

  void newchat() {
    viewController.navigate(widget.props, null);
  }

  void setCustomer(PapercupsCustomer c, {rebuild = false}) {
    log("setCustomer.... ${c.id} ${c.externalId}",
        level: 0, name: 'papercups.controller');
    if (rebuild && mounted) setState(() {});
  }

  void setConversation(Conversation c) {
    log("setConversation.... ${c.id} ${c.messages.length}",
        level: 0, name: 'papercups.controller');
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
          itemCount: messagingController.conversations.length,
          itemBuilder: (context, index) {
            Conversation conversation = messagingController.conversations[
                messagingController.conversations.keys.elementAt(index)];

            String conversationId = conversation != null ? conversation.id : "";
            String body = conversation != null
                ? conversation.messages != null
                    ? conversation.messages.isNotEmpty
                        ? conversation.messages[0].body
                        : ""
                    : ""
                : "";
            String sentAt = conversation != null
                ? conversation.createdAt != null
                    ? conversation.createdAt
                    : ""
                : "";
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
      child: _connectionState == PaperCupsConnectionState.disconnected
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
                          controller: viewController.stateMessageController,
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
