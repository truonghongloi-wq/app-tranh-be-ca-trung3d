import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class FavoriteItem {
  final String id;
  final String url;
  const FavoriteItem({required this.id, required this.url});
}

class FavoriteStore {
  static final ValueNotifier<List<FavoriteItem>> favorites =
      ValueNotifier<List<FavoriteItem>>([]);

  static bool isFavorite(String id) =>
      favorites.value.any((f) => f.id == id);

  static String _safeKey(String id) =>
      id.replaceAll(RegExp(r'[.#$\[\]/]'), '_');

  static Future<void> loadFromFirebase() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap =
          await FirebaseDatabase.instance.ref('users/$uid/favorites').get();
      if (!snap.exists) return;
      final raw = snap.value;
      if (raw is! Map) return;
      favorites.value = raw.entries
          .map((e) {
            final v = e.value;
            if (v is! Map) return null;
            return FavoriteItem(
              id: (v['id'] as String?) ?? (e.key as String),
              url: (v['url'] as String?) ?? '',
            );
          })
          .whereType<FavoriteItem>()
          .toList();
    } catch (e) {
      debugPrint('[FavoriteStore] load error: $e');
    }
  }

  static Future<void> toggle(FavoriteItem item) async {
    final current = List<FavoriteItem>.from(favorites.value);
    final idx = current.indexWhere((f) => f.id == item.id);
    if (idx >= 0) {
      current.removeAt(idx);
    } else {
      current.add(item);
    }
    favorites.value = current;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final key = _safeKey(item.id);
    try {
      if (idx >= 0) {
        await FirebaseDatabase.instance
            .ref('users/$uid/favorites/$key')
            .remove();
      } else {
        await FirebaseDatabase.instance
            .ref('users/$uid/favorites/$key')
            .set({'id': item.id, 'url': item.url});
      }
    } catch (e) {
      debugPrint('[FavoriteStore] toggle error: $e');
    }
  }
}
