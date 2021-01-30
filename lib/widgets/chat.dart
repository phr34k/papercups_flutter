import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/models.dart';

class ChatMessages extends StatelessWidget {
  final Props props;
  final List<PapercupsMessage> messages;
  final bool sending;
  final ScrollController _controller;
  final String locale;
  final timeagoLocale;
  final String sendingText;
  final String sentText;
  final Function(String) copied;
  final Color colorTextLeft;
  final Color colorTextRight;
  final Color colorLeft;
  final Color colorRight;
  final Gradient gradientLeft;
  final Gradient gradientRight;

  ChatMessages(
    this.props,
    this.messages,
    this._controller,
    this.sending,
    this.locale,
    this.timeagoLocale,
    this.sendingText,
    this.sentText, {
    this.colorLeft,
    this.colorRight,
    this.gradientLeft,
    this.gradientRight,
    this.colorTextLeft,
    this.colorTextRight,
    this.copied,
    Key key,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, layout) {
      return Container(
        alignment: Alignment.topCenter,
        child: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (OverscrollIndicatorNotification overscroll) {
            overscroll.disallowGlow();
            return false;
          },
          child: ListView.builder(
            controller: _controller,
            physics: props.scrollEnabled
                ? ClampingScrollPhysics()
                : NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              return ChatMessage(
                container: this,
                index: index,
                props: props,
                sending: sending,
                locale: locale,
                timeagoLocale: timeagoLocale,
                maxWidth: layout.maxWidth * 0.65,
                sendingText: sendingText,
                sentText: sentText,
              );
            },
          ),
        ),
      );
    });
  }
}

class ChatMessage extends StatefulWidget {
  const ChatMessage({
    Key key,
    @required this.container,
    @required this.index,
    @required this.props,
    @required this.sending,
    @required this.maxWidth,
    @required this.locale,
    @required this.timeagoLocale,
    @required this.sendingText,
    @required this.sentText,
  }) : super(key: key);

  final ChatMessages container;
  final int index;
  final Props props;
  final bool sending;
  final double maxWidth;
  final String locale;
  final timeagoLocale;
  final String sendingText;
  final String sentText;

  @override
  _ChatMessageState createState() => _ChatMessageState();
}

class _ChatMessageState extends State<ChatMessage> {
  double opacity = 0;
  double maxWidth = 0;
  bool isTimeSentVisible = false;
  String longDay;
  Timer timer;

  @override
  void dispose() {
    if (timer != null) timer.cancel();
    super.dispose();
  }

  @override
  void initState() {
    maxWidth = widget.maxWidth;
    super.initState();
  }

  TimeOfDay senderTime = TimeOfDay.now();
  @override
  Widget build(BuildContext context) {
    if (opacity == 0)
      Timer(
          Duration(
            milliseconds: 0,
          ), () {
        if (mounted)
          setState(() {
            opacity = 1;
          });
      });
    var msg = widget.container.messages[widget.index];

    bool userSent = true;
    if (msg.userId != null) userSent = false;

    var text = msg.body;
    var nextMsg = widget.container
        .messages[min(widget.index + 1, widget.container.messages.length - 1)];
    var isLast = widget.index == widget.container.messages.length - 1;
    var isFirst = widget.index == 0;

    if (!isLast) {
      DateTime sendTime = nextMsg.sentAt.toLocal();
      if ((sendTime.day != sendTime.day) && longDay == null) {
        try {
          longDay = DateFormat.yMMMMd(widget.locale).format(sendTime.toLocal());
        } catch (e) {
          print("ERROR: Error generating localized date!");
          longDay = "Loading...";
        }
      }
    }
    if (userSent && isLast && widget.timeagoLocale != null) {
      timeago.setLocaleMessages(widget.locale, widget.timeagoLocale);
      timeago.setDefaultLocale(widget.locale);
    }
    if (isLast && userSent && timer == null)
      timer = Timer.periodic(Duration(minutes: 1), (timer) {
        if (mounted && timer.isActive) {
          setState(() {});
        }
      });
    if (!isLast && timer != null) timer.cancel();
    return GestureDetector(
      onTap: () {
        setState(() {
          isTimeSentVisible = true;
        });
      },
      onLongPress: () {
        widget.container.copied(msg.body);
      },
      onTapUp: (_) {
        Timer(
            Duration(
              seconds: 10,
            ), () {
          if (mounted)
            setState(() {
              isTimeSentVisible = false;
            });
        });
      },
      child: AnimatedOpacity(
        curve: Curves.easeIn,
        duration: Duration(milliseconds: 300),
        opacity: opacity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  userSent ? MainAxisAlignment.end : MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!userSent)
                  Padding(
                    padding: EdgeInsets.only(
                      right: 14,
                      left: 14,
                      top: (isFirst) ? 15 : 4,
                      bottom: 5,
                    ),
                    child: (widget.container.messages.length == 1 ||
                            nextMsg.userId != msg.userId ||
                            isLast)
                        ? Container(
                            decoration: BoxDecoration(
                              color: userSent
                                  ? widget.container.colorLeft
                                  : widget.container.colorRight,
                              gradient: userSent
                                  ? widget.container.gradientLeft
                                  : widget.container.gradientRight,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.transparent,
                              backgroundImage:
                                  (msg.user.profilePhotoUrl != null)
                                      ? NetworkImage(msg.user.profilePhotoUrl)
                                      : null,
                              child: (msg.user.profilePhotoUrl != null)
                                  ? null
                                  : (msg.user != null &&
                                          msg.user.fullName == null)
                                      ? Text(
                                          msg.user.email
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: TextStyle(
                                              color: userSent
                                                  ? widget
                                                      .container.colorTextLeft
                                                  : widget.container
                                                      .colorTextRight),
                                        )
                                      : Text(
                                          msg.user.fullName
                                              .substring(0, 1)
                                              .toUpperCase(),
                                          style: TextStyle(
                                              color: userSent
                                                  ? widget
                                                      .container.colorTextLeft
                                                  : widget.container
                                                      .colorTextRight),
                                        ),
                            ),
                          )
                        : SizedBox(
                            width: 32,
                          ),
                  ),
                if (userSent)
                  TimeWidget(
                    userSent: userSent,
                    msg: msg,
                    isVisible: isTimeSentVisible,
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: userSent
                        ? widget.container.colorLeft
                        : widget.container.colorRight,
                    gradient: userSent
                        ? widget.container.gradientLeft
                        : widget.container.gradientRight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  constraints: BoxConstraints(
                    maxWidth: maxWidth,
                  ),
                  margin: EdgeInsets.only(
                    top: (isFirst) ? 15 : 4,
                    bottom: 4,
                    right: userSent ? 18 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 14,
                  ),
                  child: MarkdownBody(
                    data: text,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: userSent
                            ? widget.container.colorTextLeft
                            : widget.container.colorTextRight,
                      ),
                      a: TextStyle(
                        color: userSent
                            ? Colors.white
                            : Theme.of(context).textTheme.bodyText1.color,
                      ),
                      blockquotePadding: EdgeInsets.only(left: 14),
                      blockquoteDecoration: BoxDecoration(
                          border: Border(
                        left: BorderSide(color: Colors.grey[300], width: 4),
                      )),
                    ),
                  ),
                ),
                if (!userSent)
                  TimeWidget(
                    userSent: userSent,
                    msg: msg,
                    isVisible: isTimeSentVisible,
                  ),
              ],
            ),
            if (!userSent && ((nextMsg.userId != msg.userId) || (isLast)))
              Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 5, top: 4),
                  child: (msg.user.fullName == null)
                      ? Text(
                          msg.user.email,
                          style: TextStyle(
                            color: Theme.of(context)
                                .disabledColor
                                .withOpacity(0.5),
                            fontSize: 14,
                          ),
                        )
                      : Text(
                          msg.user.fullName,
                          style: TextStyle(
                            color: Theme.of(context)
                                .disabledColor
                                .withOpacity(0.5),
                            fontSize: 14,
                          ),
                        )),
            if (userSent && isLast)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(
                  bottom: 4,
                  left: 18,
                  right: 18,
                ),
                child: Text(
                  widget.sending
                      ? widget.sendingText
                      : "${widget.sentText} ${timeago.format(msg.createdAt.toLocal())}",
                  textAlign: TextAlign.end,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            if (isLast || nextMsg.userId != msg.userId)
              SizedBox(
                height: 10,
              ),
            if (longDay != null)
              IgnorePointer(
                ignoring: true,
                child: Container(
                  margin: EdgeInsets.all(15),
                  width: double.infinity,
                  child: Text(
                    longDay,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TimeWidget extends StatelessWidget {
  const TimeWidget({
    Key key,
    @required this.userSent,
    @required this.msg,
    @required this.isVisible,
  }) : super(key: key);

  final bool userSent;
  final PapercupsMessage msg;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1 : 0,
      duration: Duration(milliseconds: 100),
      curve: Curves.easeIn,
      child: Padding(
        padding: EdgeInsets.only(bottom: 5.0, left: 4, right: 4),
        child: Text(
          TimeOfDay.fromDateTime(msg.createdAt.toLocal()).format(context),
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyText1.color.withAlpha(100),
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
