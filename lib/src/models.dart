// Modèles de données FilStock.
//
// Le format JSON est volontairement identique à celui de la version web/Tauri
// (clés `id`, `brand`, `colorName`, `qty` 0-100, etc.) afin que l'import des
// anciens fichiers `filstock_data.json` / exports fonctionne sans conversion.

class Spool {
  String id;
  String brand;
  String material;
  String colorName;
  String color; // hex "#rrggbb"
  int qty; // 0-100 (%)
  String pack; // "vacuum" | "open"
  String loc; // "stock" | "inuse"
  String type; // "mounted" | "refill"
  String notes;
  List<String> traits;
  String? code;
  String? supportId;
  String createdAt; // ISO 8601
  String lastModified; // ISO 8601

  Spool({
    required this.id,
    required this.brand,
    required this.material,
    required this.colorName,
    required this.color,
    required this.qty,
    required this.pack,
    required this.loc,
    required this.type,
    required this.notes,
    required this.traits,
    required this.code,
    required this.supportId,
    required this.createdAt,
    required this.lastModified,
  });

  Spool copyWith({
    String? id,
    String? brand,
    String? material,
    String? colorName,
    String? color,
    int? qty,
    String? pack,
    String? loc,
    String? type,
    String? notes,
    List<String>? traits,
    Object? code = _noChange,
    Object? supportId = _noChange,
    String? createdAt,
    String? lastModified,
  }) {
    return Spool(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      material: material ?? this.material,
      colorName: colorName ?? this.colorName,
      color: color ?? this.color,
      qty: qty ?? this.qty,
      pack: pack ?? this.pack,
      loc: loc ?? this.loc,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      traits: traits ?? List<String>.from(this.traits),
      code: code == _noChange ? this.code : code as String?,
      supportId: supportId == _noChange ? this.supportId : supportId as String?,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'brand': brand,
        'material': material,
        'colorName': colorName,
        'color': color,
        'qty': qty,
        'pack': pack,
        'loc': loc,
        'type': type,
        'notes': notes,
        'traits': traits,
        'code': code,
        'supportId': supportId,
        'createdAt': createdAt,
        'lastModified': lastModified,
      };

  /// Lecture tolérante : champs manquants/invalides remplacés par des défauts sûrs.
  factory Spool.fromJson(Map<String, dynamic> j) {
    final hex = j['color'];
    final validHex = (hex is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex))
        ? hex
        : '#7a7a82';
    final rawQty = j['qty'];
    final qty = (rawQty is num && rawQty >= 0 && rawQty <= 100)
        ? rawQty.round()
        : 100;
    return Spool(
      id: (j['id'] as String?) ?? '',
      brand: (j['brand'] as String?) ?? 'Inconnu',
      material: (j['material'] as String?) ?? 'PLA',
      colorName: (j['colorName'] as String?) ?? 'Personnalisée',
      color: validHex,
      qty: qty,
      pack: const ['vacuum', 'open'].contains(j['pack']) ? j['pack'] : 'vacuum',
      loc: const ['stock', 'inuse'].contains(j['loc']) ? j['loc'] : 'stock',
      type:
          const ['mounted', 'refill'].contains(j['type']) ? j['type'] : 'mounted',
      notes: (j['notes'] as String?) ?? '',
      traits: (j['traits'] is List)
          ? (j['traits'] as List).whereType<String>().toList()
          : <String>[],
      code: j['code'] as String?,
      supportId: j['supportId'] as String?,
      createdAt: (j['createdAt'] as String?) ?? DateTime.now().toIso8601String(),
      lastModified:
          (j['lastModified'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }
}

const Object _noChange = Object();

class Support {
  String id;
  String type; // "normal" | "high-temp" | "very-high-temp"
  String notes;

  Support({required this.id, required this.type, required this.notes});

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'notes': notes};

  factory Support.fromJson(Map<String, dynamic> j) => Support(
        id: (j['id'] as String?) ?? '',
        type: const ['normal', 'high-temp', 'very-high-temp'].contains(j['type'])
            ? j['type']
            : 'normal',
        notes: (j['notes'] as String?) ?? '',
      );
}

class FilamentColor {
  final String name;
  final String hex;
  const FilamentColor(this.name, this.hex);

  Map<String, dynamic> toJson() => {'name': name, 'hex': hex};
  factory FilamentColor.fromJson(Map<String, dynamic> j) =>
      FilamentColor((j['name'] as String?) ?? '', (j['hex'] as String?) ?? '#000000');
}

class FieldChange {
  final String field;
  final dynamic from;
  final dynamic to;
  const FieldChange(this.field, this.from, this.to);

  Map<String, dynamic> toJson() => {'field': field, 'from': from, 'to': to};
  factory FieldChange.fromJson(Map<String, dynamic> j) =>
      FieldChange(j['field'] as String, j['from'], j['to']);
}

class JournalEntry {
  final String ts; // ISO
  final String action;
  final String entityType; // "spool" | "support"
  final String entityId;
  final String entityCode;
  final String entityLabel;
  final List<FieldChange> changes;

  const JournalEntry({
    required this.ts,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.entityCode,
    required this.entityLabel,
    required this.changes,
  });

  Map<String, dynamic> toJson() => {
        'ts': ts,
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'entityCode': entityCode,
        'entityLabel': entityLabel,
        'changes': changes.map((c) => c.toJson()).toList(),
      };

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        ts: (j['ts'] as String?) ?? DateTime.now().toIso8601String(),
        action: (j['action'] as String?) ?? 'edited',
        entityType: (j['entityType'] as String?) ?? 'spool',
        entityId: (j['entityId'] as String?) ?? '',
        entityCode: (j['entityCode'] as String?) ?? '',
        entityLabel: (j['entityLabel'] as String?) ?? '',
        changes: (j['changes'] is List)
            ? (j['changes'] as List)
                .whereType<Map>()
                .map((c) => FieldChange.fromJson(c.cast<String, dynamic>()))
                .toList()
            : <FieldChange>[],
      );
}

/// Réglages d'échelle UI (en %).
class UiSettings {
  int fontSize;
  int pastille;
  int btnSize;
  UiSettings({this.fontSize = 100, this.pastille = 100, this.btnSize = 100});

  Map<String, dynamic> toJson() =>
      {'fontSize': fontSize, 'pastille': pastille, 'btnSize': btnSize};

  factory UiSettings.fromJson(Map<String, dynamic> j) => UiSettings(
        fontSize: (j['fontSize'] as num?)?.round() ?? 100,
        pastille: (j['pastille'] as num?)?.round() ?? 100,
        btnSize: (j['btnSize'] as num?)?.round() ?? 100,
      );
}
