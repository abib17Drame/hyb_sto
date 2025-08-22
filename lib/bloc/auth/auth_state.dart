import 'package:equatable/equatable.dart';

// Fichier définissant les états possibles pour l'authentification.
// L'authentification ici signifie que l'application est appairée avec un ordinateur.

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

// État initial, avant que le statut d'authentification ne soit vérifié.
class AuthInitial extends AuthState {}

// État indiquant que l'utilisateur est authentifié (un appareil est appairé).
class AuthAuthenticated extends AuthState {}

// État indiquant que l'utilisateur n'est pas authentifié (aucun appareil appairé).
class AuthUnauthenticated extends AuthState {}
