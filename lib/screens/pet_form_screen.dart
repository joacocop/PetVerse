import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pet.dart';
import '../providers/auth_provider.dart';
import '../providers/pet_provider.dart';
import '../widgets/media_upload.dart';

/// Formulario de alta y edición de mascotas de PV3.
class PetFormScreen extends StatefulWidget {
  /// Crea el formulario; si recibe una mascota, funciona en modo edición.
  const PetFormScreen({this.pet, super.key});

  /// Mascota existente a editar.
  final Pet? pet;

  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _breedController;
  late final TextEditingController _ageController;
  late final TextEditingController _weightController;
  late final TextEditingController _photosController;
  late final TextEditingController _bioController;
  late PetType _type;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final pet = widget.pet;
    _nameController = TextEditingController(text: pet?.name ?? '');
    _breedController = TextEditingController(text: pet?.breed ?? '');
    _ageController = TextEditingController(
      text: pet == null ? '' : '${pet.age}',
    );
    _weightController = TextEditingController(
      text: pet == null ? '' : pet.weight.toStringAsFixed(1),
    );
    _photosController = TextEditingController(
      text: pet?.photos.join(', ') ?? '',
    );
    _bioController = TextEditingController(text: pet?.bio ?? '');
    _type = pet?.type ?? PetType.dog;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PetProvider>();
    final isEditing = widget.pet != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar mascota' : 'Agregar mascota'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isEditing
                            ? 'Actualiza los datos'
                            : 'Presenta a tu mascota',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre *',
                          prefixIcon: Icon(Icons.pets),
                        ),
                        validator: (value) =>
                            value != null && value.trim().isNotEmpty
                            ? null
                            : 'Ingresa un nombre.',
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<PetType>(
                        isExpanded: true,
                        initialValue: _type,
                        decoration: const InputDecoration(
                          labelText: 'Tipo *',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: PetType.values
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(_typeLabel(type)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _type = value);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _breedController,
                        decoration: const InputDecoration(
                          labelText: 'Raza',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Flex(
                        direction: MediaQuery.sizeOf(context).width < 550
                            ? Axis.vertical
                            : Axis.horizontal,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            fit: FlexFit.loose,
                            child: TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Edad (años) *',
                                prefixIcon: Icon(Icons.cake_outlined),
                              ),
                              validator: (value) {
                                final age = int.tryParse(value ?? '');
                                return age != null && age >= 0
                                    ? null
                                    : 'Edad inválida.';
                              },
                            ),
                          ),
                          const SizedBox(width: 14, height: 14),
                          Flexible(
                            fit: FlexFit.loose,
                            child: TextFormField(
                              controller: _weightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Peso (kg) *',
                                prefixIcon: Icon(Icons.monitor_weight_outlined),
                              ),
                              validator: (value) {
                                final weight = double.tryParse(
                                  (value ?? '').replaceAll(',', '.'),
                                );
                                return weight != null && weight > 0
                                    ? null
                                    : 'Peso inválido.';
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _photosController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Fotos (URLs separadas por coma)',
                          prefixIcon: Icon(Icons.photo_library_outlined),
                          hintText: 'https://foto-1.jpg, https://foto-2.jpg',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _bioController,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 240,
                        decoration: const InputDecoration(
                          labelText: 'Bio de la mascota',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      MediaUpload(
                        uid: context.read<AuthProvider>().user!.id,
                        imagesOnly: true,
                        onBusy: (value) => setState(() => _uploading = value),
                        onUploaded: (url, _) {
                          _photosController.text = [
                            if (_photosController.text.trim().isNotEmpty)
                              _photosController.text.trim(),
                            url,
                          ].join(', ');
                        },
                      ),
                      FilledButton.icon(
                        onPressed: _uploading || provider.isSaving
                            ? null
                            : _save,
                        icon: provider.isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          isEditing ? 'Guardar mascota' : 'Agregar mascota',
                        ),
                      ),
                      if (provider.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          provider.errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      return;
    }
    final pet = Pet(
      id: widget.pet?.id ?? '',
      ownerId: user.id,
      name: _nameController.text.trim(),
      type: _type,
      breed: _breedController.text.trim(),
      age: int.parse(_ageController.text),
      weight: double.parse(_weightController.text.replaceAll(',', '.')),
      photos: _photosController.text
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      bio: _bioController.text.trim(),
      createdAt: widget.pet?.createdAt ?? DateTime.now(),
    );
    final success = await context.read<PetProvider>().savePet(pet);
    if (mounted && success) {
      Navigator.of(context).pop();
    }
  }

  String _typeLabel(PetType type) => switch (type) {
    PetType.dog => 'Perro',
    PetType.cat => 'Gato',
    PetType.other => 'Otro',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _photosController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}
