// lib/login_screen.dart (StatefulWidget으로 변경)

import 'package:flutter/material.dart';
import 'auth_service.dart'; // 방금 만든 서비스 파일 임포트
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 컨트롤러: 입력 필드의 텍스트를 가져오기 위해 사용
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  
  // 임시 메시지 표시
  String _message = '';

  // ----------------------------------------------------
  // 1. 회원가입 버튼 클릭 시 로직
  // ----------------------------------------------------
  void _handleSignUp() async {
    setState(() => _message = '회원가입 중...');
    
    final user = await _authService.signUp(
      _emailController.text,
      _passwordController.text,
    );

    if (user != null) {
      setState(() => _message = '회원가입 성공! 이제 로그인하세요.');
    } else {
      setState(() => _message = '회원가입 실패. 이메일 형식 및 비밀번호(6자 이상)를 확인하세요.');
    }
  }

  // ----------------------------------------------------
  // 2. 로그인 버튼 클릭 시 로직
  // ----------------------------------------------------
  void _handleSignIn() async {
    setState(() => _message = '로그인 중...');

    final user = await _authService.signIn(
      _emailController.text,
      _passwordController.text,
    );

    if (user != null) {
      setState(() => _message = '로그인 성공! 환영합니다.');
      Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
    } else {
      setState(() => _message = '로그인 실패. 이메일/비밀번호를 확인하세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run Together SG')),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // ... (기존 UI 요소 유지) ...
            
            // 이메일 필드에 컨트롤러 연결
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            
            // 비밀번호 필드에 컨트롤러 연결
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            
            // 메시지 표시
            Text(_message, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            const SizedBox(height: 10),

            // 로그인 버튼에 로직 연결
            ElevatedButton(
              onPressed: _handleSignIn, // 로그인 로직 연결
              child: const Text('Login'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            // 회원가입 버튼에 로직 연결
            TextButton(
              onPressed: _handleSignUp, // 회원가입 로직 연결
              child: const Text('Create Account (Sign Up)'), // 텍스트 변경
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}