// lib/core/errors/failures.dart
// All domain-level failures. UI maps these to user-facing messages.
// Never expose raw exceptions past the data layer.

import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

// ─── Auth failures ──────────────────────────────────────────────────────────
final class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

final class EmailAlreadyInUseFailure extends AuthFailure {
  const EmailAlreadyInUseFailure() : super('That email is already registered.');
}

final class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure() : super('Email or password is incorrect.');
}

final class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure() : super('Your session expired. Sign in again.');
}

// ─── Network failures ────────────────────────────────────────────────────────
final class NetworkFailure extends Failure {
  const NetworkFailure() : super('No connection. Check your network.');
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure() : super('Request timed out. Try again.');
}

final class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure({this.statusCode, String message = 'Server error.'})
      : super(message);

  @override
  List<Object?> get props => [message, statusCode];
}

// ─── Data failures ───────────────────────────────────────────────────────────
final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

final class ParseFailure extends Failure {
  const ParseFailure(super.message);
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

// ─── Game failures ───────────────────────────────────────────────────────────
final class MapValidationFailure extends Failure {
  /// The base failed the automatic simulation — no valid attack path exists.
  const MapValidationFailure()
      : super('This fortress has no valid attack path. Adjust your layout.');
}

final class MapTooSimpleFailure extends Failure {
  const MapTooSimpleFailure()
      : super('Your fortress needs at least 20 placed tiles.');
}

final class MatchmakingFailure extends Failure {
  const MatchmakingFailure(super.message);
}

// ─── Permission failures ─────────────────────────────────────────────────────
final class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}
