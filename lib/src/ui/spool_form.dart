import 'package:flutter/material.dart';

import '../constants.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../utils.dart';
import 'widgets.dart';

Future<void> showSpoolForm(BuildContext context, AppStore store, {Spool? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _SpoolForm(store: store, existing: existing),
  );
}

class _SpoolForm extends StatefulWidget {
  final AppStore store;
  final Spool? existing;
  const _SpoolForm({required this.store, this.existing});

  @override
  State<_SpoolForm> createState() => _SpoolFormState();
}

class _SpoolFormState extends State<_SpoolForm> {
  late TextEditingController _brand;
  late TextEditingController _notes;
  late String _material;
  late String _color;
  late int _qty;
  late String _pack;
  late String _loc;
  late String _type;
  String? _supportId;
  late Set<String> _traits;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _brand = TextEditingController(text: s?.brand ?? 'Bambu');
    _notes = TextEditingController(text: s?.notes ?? '');
    _material = s?.material ?? 'PLA';
    if (!widget.store.allMaterials.contains(_material)) {
      _material = widget.store.allMaterials.first;
    }
    _color = s?.color ?? widget.store.allColors.first.hex;
    _qty = s?.qty ?? 100;
    _pack = s?.pack ?? 'vacuum';
    _loc = s?.loc ?? 'stock';
    _type = s?.type ?? 'mounted';
    _supportId = s?.supportId;
    _traits = {...?s?.traits};
  }

  @override
  void dispose() {
    _brand.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final brand = _brand.text.trim().isEmpty ? 'Bambu' : _brand.text.trim();
    final colorObj =
        widget.store.allColors.where((c) => c.hex == _color).firstOrNull;
    final colorName = colorObj?.name ?? closestBaseColorName(_color);
    widget.store.saveSpool(
      editingId: widget.existing?.id,
      brand: brand,
      material: _material,
      qty: _qty,
      pack: _pack,
      loc: _loc,
      type: _type,
      notes: _notes.text.trim(),
      traits: _traits.toList(),
      color: _color,
      colorName: colorName,
      supportId: _supportId,
    );
    Navigator.pop(context);
    showToast(context, _editing ? '✓ Bobine mise à jour' : '✓ Bobine ajoutée');
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Supprimer cette bobine ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true && mounted) {
      widget.store.deleteSpool(widget.existing!.id);
      Navigator.pop(context);
      showToast(context, '🗑 Bobine supprimée');
    }
  }

  void _duplicate() {
    widget.store.duplicateSpool(widget.existing!.id);
    Navigator.pop(context);
    showToast(context, '⧉ Bobine dupliquée — quantité remise à 100%');
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.store.tokens;
    final code = widget.existing?.code;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: t.bg2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: t.border),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: t.border, borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    Text(
                      _editing ? 'Modifier · ${code ?? 'bobine'}' : 'Nouvelle bobine',
                      style: TextStyle(
                          color: t.text, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _brandField(t)),
                        const SizedBox(width: 12),
                        Expanded(child: _materialField(t)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _label('COULEUR', t),
                    const SizedBox(height: 6),
                    _colorRow(t),
                    const SizedBox(height: 16),
                    _label('QUANTITÉ RESTANTE', t),
                    Row(children: [
                      Expanded(
                        child: Slider(
                          value: _qty.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 100,
                          onChanged: (v) => setState(() => _qty = v.round()),
                        ),
                      ),
                      SizedBox(
                        width: 92,
                        child: Text('${qtyToGrams(_qty)}g · $_qty%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: t.accent, fontSize: 13, fontFamily: kMono)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    _label('EMBALLAGE', t),
                    const SizedBox(height: 6),
                    _toggle(t, _pack, {'vacuum': '🔒 Sous vide', 'open': '📦 Ouvert'},
                        (v) => setState(() => _pack = v)),
                    const SizedBox(height: 16),
                    _label('EMPLACEMENT', t),
                    const SizedBox(height: 6),
                    _toggle(t, _loc, {'stock': '📦 En stock', 'inuse': '🖨 En machine'},
                        (v) => setState(() => _loc = v)),
                    const SizedBox(height: 16),
                    _label('TYPE', t),
                    const SizedBox(height: 6),
                    _toggle(t, _type,
                        {'mounted': '🔩 Sur support', 'refill': '♻ Recharge'},
                        (v) => setState(() => _type = v)),
                    const SizedBox(height: 16),
                    _label('SUPPORT DE BOBINE', t),
                    const SizedBox(height: 6),
                    _supportField(t),
                    const SizedBox(height: 16),
                    _label('CARACTÉRISTIQUES SPÉCIALES', t),
                    const SizedBox(height: 6),
                    _traitsGrid(t),
                    const SizedBox(height: 16),
                    _label('NOTES (optionnel)', t),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _notes,
                      style: TextStyle(color: t.text),
                      decoration: _inputDecoration(t, 'Commentaire libre…'),
                    ),
                    const SizedBox(height: 24),
                    _footer(t),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _label(String s, ThemeTokens t) => Text(s,
      style: TextStyle(
          color: t.text2, fontSize: 11, fontFamily: kMono, letterSpacing: 0.5));

  InputDecoration _inputDecoration(ThemeTokens t, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: t.text2),
        filled: true,
        fillColor: t.bg3,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: t.accent),
        ),
      );

  Widget _brandField(ThemeTokens t) {
    final brands = widget.store.spools.map((s) => s.brand).toSet().toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('MARQUE', t),
        const SizedBox(height: 6),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: _brand.text),
          optionsBuilder: (v) => v.text.isEmpty
              ? brands
              : brands.where(
                  (b) => b.toLowerCase().contains(v.text.toLowerCase())),
          onSelected: (v) => _brand.text = v,
          fieldViewBuilder: (ctx, controller, focus, onSubmit) {
            controller.text = _brand.text;
            controller.addListener(() => _brand.text = controller.text);
            return TextField(
              controller: controller,
              focusNode: focus,
              style: TextStyle(color: t.text),
              decoration: _inputDecoration(t, 'Bambu'),
            );
          },
        ),
      ],
    );
  }

  Widget _materialField(ThemeTokens t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('MATIÈRE', t),
        const SizedBox(height: 6),
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
              value: _material,
              dropdownColor: t.bg3,
              style: TextStyle(color: t.text, fontSize: 14),
              items: widget.store.allMaterials
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _material = v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _colorRow(ThemeTokens t) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final c in widget.store.allColors)
          GestureDetector(
            onTap: () => setState(() => _color = c.hex),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorFromHex(c.hex),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _color == c.hex ? t.text : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
          ),
        // Couleur personnalisée
        GestureDetector(
          onTap: _pickCustomColor,
          child: Container(
            width: 36,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.bg3,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.border),
            ),
            child: Icon(Icons.colorize, size: 18, color: t.text2),
          ),
        ),
      ],
    );
  }

  Future<void> _pickCustomColor() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (c) => _ColorPickerDialog(initial: _color, tokens: widget.store.tokens),
    );
    if (picked != null) setState(() => _color = picked);
  }

  Widget _toggle(ThemeTokens t, String current, Map<String, String> options,
      ValueChanged<String> onSelect) {
    return Row(
      children: [
        for (final entry in options.entries) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: current == entry.key ? t.accent : t.bg3,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: current == entry.key ? t.accent : t.border),
                ),
                child: Text(entry.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: current == entry.key ? Colors.white : t.text2,
                        fontSize: 11,
                        fontFamily: kMono)),
              ),
            ),
          ),
          if (entry.key != options.keys.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _supportField(ThemeTokens t) {
    // Sélectionnables : supports libres + celui déjà assigné à cette bobine.
    final selectable = widget.store.supports.where((sup) {
      final holder = widget.store.supportHolder(sup.id);
      return holder == null || holder.id == widget.existing?.id;
    }).toList();
    final value = (_supportId != null &&
            selectable.any((s) => s.id == _supportId))
        ? _supportId
        : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.bg3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: value,
          dropdownColor: t.bg3,
          style: TextStyle(color: t.text, fontSize: 14),
          hint: Text('— Aucun support —', style: TextStyle(color: t.text2)),
          items: [
            DropdownMenuItem<String?>(
                value: null,
                child: Text('— Aucun support —',
                    style: TextStyle(color: t.text2))),
            for (final sup in selectable)
              DropdownMenuItem<String?>(
                value: sup.id,
                child: Text(
                    '${supportTypeIcon(sup.type)} ${sup.id}${sup.notes.isNotEmpty ? ' · ${sup.notes}' : ''}'),
              ),
          ],
          onChanged: (v) => setState(() => _supportId = v),
        ),
      ),
    );
  }

  Widget _traitsGrid(ThemeTokens t) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final trait in kTraits)
          GestureDetector(
            onTap: () => setState(() {
              if (!_traits.remove(trait.id)) _traits.add(trait.id);
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: _traits.contains(trait.id)
                    ? colorFromHex(trait.color).withValues(alpha: 0.15)
                    : t.bg3,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _traits.contains(trait.id)
                      ? colorFromHex(trait.color)
                      : t.border,
                  width: 1.5,
                ),
              ),
              child: Text('${trait.icon} ${trait.label}',
                  style: TextStyle(
                      color: _traits.contains(trait.id)
                          ? colorFromHex(trait.color)
                          : t.text2,
                      fontSize: 11,
                      fontFamily: kMono,
                      fontWeight: _traits.contains(trait.id)
                          ? FontWeight.w600
                          : FontWeight.normal)),
            ),
          ),
      ],
    );
  }

  Widget _footer(ThemeTokens t) {
    final buttons = <Widget>[
      if (_editing)
        OutlinedButton(
          onPressed: _confirmDelete,
          style: OutlinedButton.styleFrom(
            foregroundColor: t.danger,
            side: BorderSide(color: t.danger),
          ),
          child: const Text('🗑 Supprimer'),
        ),
      if (_editing)
        OutlinedButton(
          onPressed: _duplicate,
          style: OutlinedButton.styleFrom(
            foregroundColor: t.text,
            side: BorderSide(color: t.border),
          ),
          child: const Text('⧉ Dupliquer'),
        ),
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: t.text,
          side: BorderSide(color: t.border),
        ),
        child: const Text('Annuler'),
      ),
      ElevatedButton(
        onPressed: _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: Colors.white,
        ),
        child: const Text('Enregistrer'),
      ),
    ];
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 10,
      children: buttons,
    );
  }
}

/// Petit sélecteur de couleur : palette étendue + saisie hex.
class _ColorPickerDialog extends StatefulWidget {
  final String initial;
  final ThemeTokens tokens;
  const _ColorPickerDialog({required this.initial, required this.tokens});

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late String _hex;
  late TextEditingController _ctrl;

  // Palette étendue (teintes courantes de filament).
  static const _palette = [
    '#1a1a1a', '#444444', '#888888', '#cccccc', '#f0eeea', '#ffffff',
    '#e83030', '#b91c1c', '#ff6d1f', '#ffa500', '#ffd600', '#facc15',
    '#84cc16', '#1db954', '#059669', '#14b8a6', '#06b6d4', '#1a78e8',
    '#2563eb', '#4f46e5', '#8844ee', '#a855f7', '#ec4899', '#ff4dad',
    '#8b5e3c', '#a16207', '#c8d8e8', '#fbbf24', '#10b981', '#f43f5e',
  ];

  @override
  void initState() {
    super.initState();
    _hex = widget.initial;
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setHex(String v) {
    var h = v.trim();
    if (!h.startsWith('#')) h = '#$h';
    if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(h)) {
      setState(() => _hex = h);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    return AlertDialog(
      backgroundColor: t.bg2,
      title: Text('Couleur personnalisée', style: TextStyle(color: t.text)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _palette)
                GestureDetector(
                  onTap: () {
                    setState(() => _hex = c);
                    _ctrl.text = c;
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: colorFromHex(c),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _hex.toLowerCase() == c ? t.text : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorFromHex(_hex),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: t.border),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: TextStyle(color: t.text, fontFamily: kMono),
                decoration: InputDecoration(
                  hintText: '#rrggbb',
                  hintStyle: TextStyle(color: t.text2),
                  filled: true,
                  fillColor: t.bg3,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: t.border),
                  ),
                ),
                onChanged: _setHex,
              ),
            ),
          ]),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _hex),
          style: ElevatedButton.styleFrom(
              backgroundColor: t.accent, foregroundColor: Colors.white),
          child: const Text('Choisir'),
        ),
      ],
    );
  }
}
