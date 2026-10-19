import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/pet.dart';
import '../providers/pet_provider.dart';
import '../providers/profile_provider.dart';
import 'pet_form_screen.dart';

/// Pantalla de PV2 y PV3: perfil editable y mascotas del usuario.
class ProfileScreen extends StatefulWidget {
  /// Crea la pantalla para un usuario autenticado.
  const ProfileScreen({required this.user, super.key});

  /// Usuario autenticado.
  final AppUser user;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _photoController = TextEditingController();
  final _bioController = TextEditingController();
  String? _loadedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedUserId == widget.user.id) {
      return;
    }
    _loadedUserId = widget.user.id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) {
      return;
    }
    final profileProvider = context.read<ProfileProvider>();
    await Future.wait([
      profileProvider.loadProfile(
        userId: widget.user.id,
        email: widget.user.email,
        displayName: widget.user.displayName,
      ),
      context.read<PetProvider>().loadPets(widget.user.id),
    ]);
    if (!mounted) {
      return;
    }
    final profile = profileProvider.profile;
    if (profile != null) {
      _nameController.text = profile.name;
      _photoController.text = profile.photoUrl;
      _bioController.text = profile.bio;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth >= 900 ? 48.0 : 20.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding, 24, padding, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHero(user: widget.user),
                  const SizedBox(height: 20),
                  _buildProfileCard(),
                  const SizedBox(height: 20),
                  _buildPetsSection(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileCard() {
    final profileProvider = context.watch<ProfileProvider>();
    if (profileProvider.isLoading && profileProvider.profile == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Editar perfil',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => value != null && value.trim().length >= 2
                    ? null
                    : 'Ingresa al menos 2 caracteres.',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _photoController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL de foto de perfil',
                  prefixIcon: Icon(Icons.image_outlined),
                  hintText: 'https://...',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bioController,
                minLines: 3,
                maxLines: 5,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: profileProvider.isSaving ? null : _saveProfile,
                  icon: profileProvider.isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Guardar cambios'),
                ),
              ),
              if (profileProvider.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  profileProvider.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPetsSection() {
    final petsProvider = context.watch<PetProvider>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mis mascotas',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _openPetForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (petsProvider.isLoading && petsProvider.pets.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (petsProvider.pets.isEmpty)
              const _EmptyPets()
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 760 ? 3 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: columns == 1 ? 3.6 : 1.45,
                    ),
                    itemCount: petsProvider.pets.length,
                    itemBuilder: (context, index) => _PetCard(
                      pet: petsProvider.pets[index],
                      onEdit: () => _openPetForm(petsProvider.pets[index]),
                      onDelete: () => _deletePet(petsProvider.pets[index]),
                    ),
                  );
                },
              ),
            if (petsProvider.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                petsProvider.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final success = await context.read<ProfileProvider>().saveProfile(
          name: _nameController.text,
          photoUrl: _photoController.text,
          bio: _bioController.text,
        );
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado.')),
      );
    }
  }

  Future<void> _openPetForm([Pet? pet]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => PetFormScreen(pet: pet)),
    );
  }

  Future<void> _deletePet(Pet pet) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar mascota'),
        content: Text('¿Quieres eliminar a ${pet.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (mounted && shouldDelete == true) {
      await context.read<PetProvider>().deletePet(pet);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photoController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundImage: user.photoUrl == null || user.photoUrl!.isEmpty
              ? null
              : NetworkImage(user.photoUrl!),
          child: user.photoUrl == null || user.photoUrl!.isEmpty
              ? const Icon(Icons.person, size: 34)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hola, ${user.displayName?.isNotEmpty == true ? user.displayName : 'amigo'}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(user.email),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyPets extends StatelessWidget {
  const _EmptyPets();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.pets_outlined, size: 40),
          SizedBox(height: 8),
          Text('Todavía no registraste mascotas.'),
          SizedBox(height: 4),
          Text('Agrega la primera para completar tu perfil.'),
        ],
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({
    required this.pet,
    required this.onEdit,
    required this.onDelete,
  });

  final Pet pet;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage:
                pet.photos.isEmpty ? null : NetworkImage(pet.photos.first),
            child: pet.photos.isEmpty ? const Icon(Icons.pets) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  pet.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                    '${pet.typeLabel} · ${pet.breed.isEmpty ? 'Sin raza' : pet.breed}'),
                Text('${pet.age} años · ${pet.weight.toStringAsFixed(1)} kg'),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }
}
