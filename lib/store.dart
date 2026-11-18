import 'package:shared_preferences/shared_preferences.dart';
import 'model.dart';

class BodyStore {
  static const key = 'bodylog.v1';
  Future<BodyData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    return raw == null ? BodyData() : BodyData.decode(raw);
  }

  Future<void> save(BodyData data) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(key, data.encode())) {
      throw StateError('本地存储写入失败');
    }
  }
}
