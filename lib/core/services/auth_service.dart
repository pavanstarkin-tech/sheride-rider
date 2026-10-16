import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'storage_service.dart';

class AuthService extends ChangeNotifier {
  FirebaseAuth? _firebaseAuth;
  final StorageService _storageService;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '18953853541-5sfc1344cq4n11ube3lg8qm9mle6kqrl.apps.googleusercontent.com',
  );

  User? _user;
  String? _verificationId;
  int? _resendToken;
  bool _isLoading = false;
  String? _errorMessage;

  AuthService({
    FirebaseAuth? firebaseAuth,
    StorageService? storageService,
  })  : _firebaseAuth = firebaseAuth,
        _storageService = storageService ?? StorageService() {
    _initAuth();
  }

  void _initAuth() {
    try {
      _firebaseAuth ??= FirebaseAuth.instance;
      _user = _firebaseAuth?.currentUser;
      _firebaseAuth?.authStateChanges().listen((User? user) {
        _user = user;
        notifyListeners();
      });
    } catch (e) {
      debugPrint("AuthService (Rider) running in mock/local mode: $e");
    }
  }

  FirebaseAuth? get auth => _firebaseAuth;
  User? get currentUser => _user ?? _firebaseAuth?.currentUser;
  bool get isAuthenticated => currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get verificationId => _verificationId;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // 1. Phone Authentication: Send OTP
  Future<void> signInWithPhone(
    String phoneNumber, {
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onVerificationFailed,
    Function(PhoneAuthCredential credential)? onVerificationCompleted,
    Function(String verificationId)? onCodeAutoRetrievalTimeout,
  }) async {
    setLoading(true);
    setError(null);

    if (_firebaseAuth == null) {
      try {
        _firebaseAuth = FirebaseAuth.instance;
      } catch (_) {}
    }

    if (_firebaseAuth == null) {
      _verificationId = 'mock_ver_rider_${DateTime.now().millisecondsSinceEpoch}';
      _resendToken = 123456;
      setLoading(false);
      onCodeSent(_verificationId!, _resendToken);
      return;
    }

    try {
      await _firebaseAuth!.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final userCredential = await _firebaseAuth!.signInWithCredential(credential);
            _user = userCredential.user;
            if (userCredential.user != null) {
              await _ensureRiderProfileInDatabase(userCredential.user!);
            }
            await _persistUserSession(userCredential.user);
            setLoading(false);
            if (onVerificationCompleted != null) {
              onVerificationCompleted(credential);
            }
          } catch (e) {
            setError(e.toString());
            setLoading(false);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setError(e.message ?? 'Phone verification failed');
          setLoading(false);
          onVerificationFailed(e.message ?? 'Phone verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          setLoading(false);
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          if (onCodeAutoRetrievalTimeout != null) {
            onCodeAutoRetrievalTimeout(verificationId);
          }
        },
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      _verificationId = 'mock_ver_rider_${DateTime.now().millisecondsSinceEpoch}';
      setLoading(false);
      onCodeSent(_verificationId!, null);
    }
  }

  // 2. Verify OTP
  Future<UserCredential?> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    setLoading(true);
    setError(null);

    if (_firebaseAuth == null) {
      try {
        _firebaseAuth = FirebaseAuth.instance;
      } catch (_) {}
    }

    if (_firebaseAuth == null) {
      setLoading(false);
      return null;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCredential = await _firebaseAuth!.signInWithCredential(credential);
      _user = userCredential.user;
      if (userCredential.user != null) {
        await _ensureRiderProfileInDatabase(userCredential.user!);
      }
      await _persistUserSession(userCredential.user);
      setLoading(false);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      setError(e.message ?? 'Invalid OTP');
      setLoading(false);
      rethrow;
    } catch (e) {
      setError(e.toString());
      setLoading(false);
      rethrow;
    }
  }

  // 3. Google Sign-In with real account chooser bottom sheet & RTDB profile persistence
  Future<UserCredential?> signInWithGoogle() async {
    setLoading(true);
    setError(null);

    try {
      // 1. Trigger the native Google Account chooser modal/bottom-sheet
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Captain dismissed / cancelled account chooser
        setLoading(false);
        return null;
      }

      // 2. Obtain authentication credentials
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3. Authenticate with Firebase
      _firebaseAuth ??= FirebaseAuth.instance;
      final userCredential = await _firebaseAuth!.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        _user = user;
        // 4. Properly store captain profile & wallet in Firebase Realtime Database
        await _ensureRiderProfileInDatabase(user, googleUser: googleUser);
        await _persistUserSession(user);
      }

      setLoading(false);
      notifyListeners();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      setError(_mapAuthError(e.code, e.message));
      setLoading(false);
      return null;
    } catch (e) {
      debugPrint("Captain Google Sign-In error: $e");
      setError("Google Sign-In failed. Please try again.");
      setLoading(false);
      return null;
    }
  }

  // 4. Email & Password Sign In
  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    setLoading(true);
    setError(null);

    if (_firebaseAuth == null) {
      try {
        _firebaseAuth = FirebaseAuth.instance;
      } catch (_) {}
    }

    if (_firebaseAuth == null) {
      setLoading(false);
      return null;
    }

    try {
      final userCredential = await _firebaseAuth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _user = userCredential.user;
      if (userCredential.user != null) {
        await _ensureRiderProfileInDatabase(userCredential.user!);
      }
      await _persistUserSession(userCredential.user);
      setLoading(false);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      setError(e.message ?? 'Sign in failed');
      setLoading(false);
      rethrow;
    } catch (e) {
      setError(e.toString());
      setLoading(false);
      rethrow;
    }
  }

  // 5. Email & Password Registration
  Future<UserCredential?> registerWithEmailPassword(String email, String password) async {
    setLoading(true);
    setError(null);

    if (_firebaseAuth == null) {
      try {
        _firebaseAuth = FirebaseAuth.instance;
      } catch (_) {}
    }

    if (_firebaseAuth == null) {
      setLoading(false);
      return null;
    }

    try {
      final userCredential = await _firebaseAuth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _user = userCredential.user;
      if (userCredential.user != null) {
        await _ensureRiderProfileInDatabase(userCredential.user!);
      }
      await _persistUserSession(userCredential.user);
      setLoading(false);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      setError(e.message ?? 'Registration failed');
      setLoading(false);
      rethrow;
    } catch (e) {
      setError(e.toString());
      setLoading(false);
      rethrow;
    }
  }

  // 5. Send Password Reset Email
  Future<bool> sendPasswordResetEmail(String email) async {
    setLoading(true);
    setError(null);
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      setError('Please enter a valid email address');
      setLoading(false);
      return false;
    }

    if (_firebaseAuth != null) {
      try {
        await _firebaseAuth!.sendPasswordResetEmail(email: cleanEmail);
        setLoading(false);
        return true;
      } on FirebaseAuthException catch (e) {
        setError(_mapAuthError(e.code, e.message));
        setLoading(false);
        return false;
      } catch (e) {
        setError(e.toString());
        setLoading(false);
        return false;
      }
    }
    setLoading(false);
    return true;
  }

  // 6. Send Email Verification
  Future<bool> sendEmailVerification() async {
    try {
      final user = _firebaseAuth?.currentUser ?? _user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        return true;
      }
    } catch (e) {
      debugPrint("Captain email verification notice: $e");
    }
    return false;
  }

  // 7. Check if Email is Verified
  bool get isEmailVerified => (_user ?? _firebaseAuth?.currentUser)?.emailVerified ?? true;

  // 8. Reload User State
  Future<void> reloadUser() async {
    try {
      await _firebaseAuth?.currentUser?.reload();
      _user = _firebaseAuth?.currentUser;
      notifyListeners();
    } catch (_) {}
  }

  // 9. Map Firebase Auth Errors
  String _mapAuthError(String code, String? defaultMsg) {
    switch (code) {
      case 'user-not-found':
        return 'No Lady Pilot Captain account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Please try again or reset your password.';
      case 'email-already-in-use':
        return 'A captain account already exists with this email. Please log in.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password should be at least 6 characters long.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact Lady Pilot Support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return defaultMsg ?? 'Authentication failed. Please try again.';
    }
  }

  // 10. Get Firebase ID Token
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    if (_user == null) {
      return await _storageService.getAuthToken();
    }
    final token = await _user?.getIdToken(forceRefresh);
    if (token != null) {
      await _storageService.saveAuthToken(token);
    }
    return token;
  }

  // 11. Persist Session
  Future<void> _persistUserSession(User? user) async {
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) {
        await _storageService.saveAuthToken(token);
      }
      await _storageService.saveUserId(user.uid);
      await _storageService.saveUserRole('rider');
    }
  }

  // 12. Sign Out
  Future<void> signOut() async {
    setLoading(true);
    try {
      if (_firebaseAuth != null) {
        await _firebaseAuth!.signOut();
      }
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      _user = null;
      _verificationId = null;
      await _storageService.clearSession();
      setLoading(false);
      notifyListeners();
    } catch (e) {
      setError(e.toString());
      setLoading(false);
    }
  }

  // 13. Ensure full rider profile & wallet exist in Firebase Realtime Database
  Future<void> _ensureRiderProfileInDatabase(User user, {GoogleSignInAccount? googleUser}) async {
    try {
      final db = FirebaseDatabase.instance;
      final riderRef = db.ref('riders/${user.uid}');
      final snap = await riderRef.get();
      final now = DateTime.now().millisecondsSinceEpoch;

      final name = user.displayName?.isNotEmpty == true
          ? user.displayName!
          : (googleUser?.displayName?.isNotEmpty == true
              ? googleUser!.displayName!
              : (user.email?.split('@').first ?? 'Lady Captain'));
      final email = user.email ?? (googleUser?.email ?? '');
      final photoUrl = user.photoURL ?? (googleUser?.photoUrl ?? '');

      if (!snap.exists || snap.value == null) {
        // Complete Rider Profile creation in /riders/{uid}
        await riderRef.set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'phone': user.phoneNumber ?? '',
          'gender': 'Female',
          'profileImageUrl': photoUrl,
          'vehicleType': 'Scooty',
          'vehicleNumber': '',
          'verificationStatus': 'pending',
          'isVerified': false,
          'isOnline': false,
          'isBlocked': false,
          'rating': 5.0,
          'totalRides': 0,
          'role': 'rider',
          'createdAt': now,
          'lastLoginAt': now,
        });

        // Initialize rider wallet with 0.0 balance
        await db.ref('wallets/${user.uid}').set({
          'balance': 0.0,
          'currency': 'INR',
          'updatedAt': now,
        });
      } else {
        // Existing rider: Update lastLoginAt and any missing fields
        final Map<String, dynamic> updates = {
          'lastLoginAt': now,
        };
        if (photoUrl.isNotEmpty) updates['profileImageUrl'] = photoUrl;
        if (name.isNotEmpty && name != 'Lady Captain') updates['name'] = name;
        if (email.isNotEmpty) updates['email'] = email;

        await riderRef.update(updates);
      }
    } catch (e) {
      debugPrint("Realtime DB error in _ensureRiderProfileInDatabase: $e");
    }
  }
}

