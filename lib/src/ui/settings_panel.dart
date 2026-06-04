import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _materialCtrl = TextEditingController();
  final _colorNameCtrl = TextEditingController();
  final _supportNotesCtrl = TextEditingController();
  String _colorHex = '#ff0000';
  String _supportType = 'normal';

  @override
  void dispose() {
    _materialCtrl.dispose();
    _colorNameCtrl.dispose();
    _supportNotesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final t = store.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg2,
        foregroundColor: t.text,
        title: const Text('⚙ Réglages'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          _section('Apparence', t),
          _slider(t, 'Taille de police globale', store.settings.fontSize, 75, 130, 11,
              (v) => store.setSettings(fontSize: v)),
          _slider(t, 'Texte dans les pastilles', store.settings.pastille, 50, 200, 15,
              (v) => store.setSettings(pastille: v)),
          _slider(t, 'Taille boutons & icônes', store.settings.btnSize, 70, 150, 16,
              (v) => store.setSettings(btnSize: v)),
          const SizedBox(height: 28),
          _section('Supports de bobine', t),
          _supportsList(store, t),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: t.bg3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _supportType,
                dropdownColor: t.bg3,
                style: TextStyle(color: t.text, fontSize: 13),
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('🔩 Normal (~60°C, PLA)')),
                  DropdownMenuItem(
                      value: 'high-temp', child: Text('🌡️ Haute temp. (~90°C, PETG/ABS)')),
                  DropdownMenuItem(
                      value: 'very-high-temp',
                      child: Text('🔥 Très haute temp. (>90°C, PA-CF)')),
                ],
                onChanged: (v) => setState(() => _supportType = v!),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _supportNotesCtrl,
                maxLength: 30,
                style: TextStyle(color: t.text),
                decoration: _input(t, 'Notes optionnelles…').copyWith(counterText: ''),
              ),
            ),
            const SizedBox(width: 8),
            _addButton(t, () {
              final id = store.addSupport(_supportType, _supportNotesCtrl.text.trim());
              _supportNotesCtrl.clear();
              showToast(context, '✓ Support $id créé');
            }, '＋ Ajouter'),
          ]),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Prochain ID : ${store.generateSupportId(_supportType)}',
                style: TextStyle(color: t.text2, fontSize: 11, fontFamily: kMono)),
          ),
          const SizedBox(height: 28),
          _section('Matières personnalisées', t),
          _materialsList(store, t),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _materialCtrl,
                maxLength: 12,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(color: t.text),
                decoration: _input(t, 'Ex: SILK, CLAY…').copyWith(counterText: ''),
                onSubmitted: (_) => _addMaterial(store),
              ),
            ),
            const SizedBox(width: 8),
            _addButton(t, () => _addMaterial(store), '＋ Ajouter'),
          ]),
          const SizedBox(height: 28),
          _section('Couleurs personnalisées', t),
          _colorsList(store, t),
          const SizedBox(height: 8),
          Row(children: [
            GestureDetector(
              onTap: () async {
                // Réutilise la saisie hex simple.
                final ctrl = TextEditingController(text: _colorHex);
                final res = await showDialog<String>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: t.bg2,
                    title: Text('Couleur', style: TextStyle(color: t.text)),
                    content: TextField(
                      controller: ctrl,
                      style: TextStyle(color: t.text, fontFamily: kMono),
                      decoration: _input(t, '#rrggbb'),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Annuler')),
                      ElevatedButton(
                          onPressed: () => Navigator.pop(c, ctrl.text.trim()),
                          child: const Text('OK')),
                    ],
                  ),
                );
                if (res != null) {
                  var h = res.startsWith('#') ? res : '#$res';
                  if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(h)) {
                    setState(() {
                      _colorHex = h;
                      if (_colorNameCtrl.text.trim().isEmpty) {
                        _colorNameCtrl.text = closestBaseColorName(h);
                      }
                    });
                  }
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorFromHex(_colorHex),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: t.border),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _colorNameCtrl,
                maxLength: 16,
                style: TextStyle(color: t.text),
                decoration: _input(t, 'Nom de la couleur').copyWith(counterText: ''),
                onSubmitted: (_) => _addColor(store),
              ),
            ),
            const SizedBox(width: 8),
            _addButton(t, () => _addColor(store), '＋'),
          ]),
        ],
      ),
    );
  }

  void _addMaterial(AppStore store) {
    final v = _materialCtrl.text;
    if (v.trim().isEmpty) {
      showToast(context, '⚠ Saisir une matière');
      return;
    }
    if (store.addMaterial(v)) {
      _materialCtrl.clear();
      showToast(context, '✓ Matière ajoutée');
    } else {
      showToast(context, '⚠ Matière déjà existante');
    }
  }

  void _addColor(AppStore store) {
    if (_colorNameCtrl.text.trim().isEmpty) {
      showToast(context, '⚠ Saisir un nom de couleur');
      return;
    }
    if (store.addColor(_colorNameCtrl.text, _colorHex)) {
      _colorNameCtrl.clear();
      setState(() => _colorHex = '#ff0000');
      showToast(context, '✓ Couleur ajoutée');
    } else {
      showToast(context, '⚠ Couleur déjà existante');
    }
  }

  Widget _section(String title, ThemeTokens t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          child: Text(title.toUpperCase(),
              style: TextStyle(
                  color: t.text2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
        ),
      );

  Widget _slider(ThemeTokens t, String label, int value, int min, int max, int step,
      ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: t.text, fontSize: 13, fontWeight: FontWeight.w600))),
            Text('$value%',
                style: TextStyle(color: t.accent, fontSize: 12, fontFamily: kMono)),
          ]),
          Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: ((max - min) / step).round(),
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }

  InputDecoration _input(ThemeTokens t, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: t.text2),
        filled: true,
        fillColor: t.bg3,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: t.accent),
        ),
      );

  Widget _addButton(ThemeTokens t, VoidCallback onTap, String label) => ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        child: Text(label),
      );

  Widget _supportsList(AppStore store, ThemeTokens t) {
    if (store.supports.isEmpty) {
      return Text('Aucun support créé.', style: TextStyle(color: t.text2, fontSize: 12));
    }
    return Column(
      children: store.supports.map((sup) {
        final holder = store.supportHolder(sup.id);
        final canDel = holder == null;
        final style = supportBadgeStyle(sup.type, t);
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: t.bg3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.border),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: style.bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: style.border),
              ),
              child: Text(supportTypeIcon(sup.type),
                  style: TextStyle(color: style.fg, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${sup.id}${sup.notes.isNotEmpty ? ' · ${sup.notes}' : ''}'
                '${holder != null ? '  → ${holder.code ?? holder.brand}' : ''}',
                style: TextStyle(color: t.text, fontSize: 13),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close,
                  size: 16, color: canDel ? t.text2 : t.text2.withValues(alpha: 0.3)),
              onPressed: canDel
                  ? () {
                      store.deleteSupport(sup.id);
                      showToast(context, '🗑 Support ${sup.id} supprimé');
                    }
                  : () => showToast(context,
                      '⚠ Support assigné à ${holder.code ?? holder.brand}'),
            ),
          ]),
        );
      }).toList(),
    );
  }

  Widget _materialsList(AppStore store, ThemeTokens t) {
    if (store.customMaterials.isEmpty) {
      return Text('Aucune matière personnalisée.',
          style: TextStyle(color: t.text2, fontSize: 12));
    }
    return Column(
      children: [
        for (var i = 0; i < store.customMaterials.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: t.bg3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.border),
            ),
            child: Row(children: [
              Expanded(
                  child: Text(store.customMaterials[i],
                      style: TextStyle(
                          color: t.text, fontSize: 13, fontWeight: FontWeight.w600))),
              IconButton(
                icon: Icon(Icons.close, size: 16, color: t.text2),
                onPressed: () => store.removeMaterial(i),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _colorsList(AppStore store, ThemeTokens t) {
    if (store.customColors.isEmpty) {
      return Text('Aucune couleur personnalisée.',
          style: TextStyle(color: t.text2, fontSize: 12));
    }
    return Column(
      children: [
        for (var i = 0; i < store.customColors.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: t.bg3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.border),
            ),
            child: Row(children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: colorFromHex(store.customColors[i].hex),
                  shape: BoxShape.circle,
                  border: Border.all(color: t.border),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(store.customColors[i].name,
                      style: TextStyle(
                          color: t.text, fontSize: 13, fontWeight: FontWeight.w600))),
              IconButton(
                icon: Icon(Icons.close, size: 16, color: t.text2),
                onPressed: () => store.removeColor(i),
              ),
            ]),
          ),
      ],
    );
  }
}
