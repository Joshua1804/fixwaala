/// Marker for exceptions whose `message` is already written for a user.
///
/// Services throw these for conditions the user can understand and often act
/// on — "this job has already been paid", "your account is restricted". UI can
/// surface [message] verbatim; anything *not* implementing this is an internal
/// fault and must be mapped to generic copy by `ErrorMessages.friendly`.
abstract class UserFacingException implements Exception {
  String get message;
}
