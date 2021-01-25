/// This class is used for the agent sending the messages.
class User {
  /// The time the agent was created.
  DateTime createdAt;

  /// The time the agent was disabled. If null, agent is enabled.
  DateTime disabledAt;

  ///  The email of the agent.
  String email;

  /// The unique ID of the person in Papercups, is an integer but converted to string so it can be nullable
  String id;

  /// The role of the agent.
  String role;

  /// The name of the agent. May be null.
  String fullName;

  /// The profile photo of the agent, must be a valid URL or null.
  String profilePhotoUrl;

  User({
    this.createdAt,
    this.disabledAt,
    this.email,
    this.id,
    this.role,
    this.fullName,
    this.profilePhotoUrl,
  });
}
