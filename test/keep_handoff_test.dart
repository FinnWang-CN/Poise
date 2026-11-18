import 'package:bodylog/keep_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Keep handoff encodes official authorization URL and rejects unrelated links',
    () async {
      final redirect = Uri.parse(
        'https://show.gotokeep.com/login/auth?qrcodeId=fixture&authType=my',
      );
      final link = keepAuthorizationLink(redirect);
      expect(link.scheme, 'keep');
      expect(link.host, 'webview');
      expect(link.pathSegments.single, redirect.toString());
      expect(link.queryParameters['isExternalLaunch'], '1');
      for (final invalid in [
        'https://evil.example/login/auth',
        'http://show.gotokeep.com/login/auth',
        'https://show.gotokeep.com/other',
        'https://user@show.gotokeep.com/login/auth',
        'https://show.gotokeep.com:444/login/auth',
        'https://show.gotokeep.com/login/auth#other',
      ]) {
        expect(
          () => keepAuthorizationLink(Uri.parse(invalid)),
          throwsA(isA<KeepException>()),
        );
      }
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(KeepService.appChannel, (call) async {
            calls.add(call);
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(KeepService.appChannel, null),
      );
      final api = KeepService();
      addTearDown(api.dispose);
      expect(await api.isAppInstalled(), isTrue);
      expect(
        await api.openAuthorization(
          KeepLogin(
            'fixture',
            Uri.parse('https://api.gotokeep.com/image'),
            redirect,
          ),
        ),
        isTrue,
      );
      expect(calls.map((c) => c.method), ['isInstalled', 'openAuthorization']);
      expect(calls.last.arguments, {'url': link.toString()});
    },
  );
}
