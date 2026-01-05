// lib/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. 회원가입 (Sign Up)
  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user; // 가입 성공 시 사용자 객체 반환
    } on FirebaseAuthException catch (e) {
      // Firebase에서 발생한 구체적인 오류 처리 (예: 이미 등록된 이메일)
      print('회원가입 오류: ${e.code}');
      // 사용자에게 보여줄 메시지를 반환하거나, 오류를 다시 던질 수 있습니다.
      return null;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // 2. 로그인 (Sign In)
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user; // 로그인 성공 시 사용자 객체 반환
    } on FirebaseAuthException catch (e) {
      // 구체적인 오류 처리 (예: 잘못된 비밀번호, 사용자 없음)
      print('로그인 오류: ${e.code}');
      return null;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // 3. 로그아웃 (Sign Out)
  Future<void> signOut() async {
    await _auth.signOut();
  }
}