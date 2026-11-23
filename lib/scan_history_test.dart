import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/scan_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'completed scans survive a cache reload and stay isolated per user',
    () async {
      SharedPreferences.setMockInitialValues({});
      await ScanHistory.save('first', {'id': 'scan', 'name': 'Food'});
      await (await SharedPreferences.getInstance()).reload();
      expect((await ScanHistory.read('first')).single['name'], 'Food');
      expect(await ScanHistory.read('second'), isEmpty);
    },
  );

  test('concurrent saves keep the newest twenty distinct scans', () async {
    SharedPreferences.setMockInitialValues({});
    await Future.wait(
      List.generate(23, (i) => ScanHistory.save('owner', {'id': '$i'})),
    );
    await ScanHistory.save('owner', {'id': '20', 'name': 'updated'});
    final entries = await ScanHistory.read('owner');
    expect(entries.length, 20);
    expect(entries.first['name'], 'updated');
    expect(entries.last['id'], '3');
    expect(entries.map((item) => item['id']).toSet().length, 20);
  });
}
