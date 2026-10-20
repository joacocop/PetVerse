import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../models/community.dart';
import '../models/pet.dart';
import '../models/post.dart';
import '../providers/pet_provider.dart';
import '../services/community_service.dart';
import '../widgets/feed_author.dart';
import '../widgets/post_media.dart';
import 'chat_screen.dart';
import 'pet_form_screen.dart';

/// Grilla de adopciones con filtros combinables y publicación de mascotas propias.
class AdoptionsScreen extends StatefulWidget {
  const AdoptionsScreen({required this.user, super.key});
  final AppUser user;
  @override
  State<AdoptionsScreen> createState() => _AdoptionsScreenState();
}

class _AdoptionsScreenState extends State<AdoptionsScreen> {
  late final _listings = context.read<CommunityService>().adoptions();
  PetType? _type;
  String _age = 'all';
  String _location = '';
  bool _mine = false;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1150),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 12,
              children: [
                Text(
                  'Un hogar para cada huella',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PublishAdoptionScreen(user: widget.user),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Publicar adopción'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: 'all',
                    decoration: const InputDecoration(
                      labelText: 'Tipo de mascota',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('Todos')),
                      DropdownMenuItem(value: 'dog', child: Text('Perros')),
                      DropdownMenuItem(value: 'cat', child: Text('Gatos')),
                      DropdownMenuItem(value: 'other', child: Text('Otros')),
                    ],
                    onChanged: (v) => setState(
                      () =>
                          _type = v == 'all' ? null : PetType.values.byName(v!),
                    ),
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _age,
                    decoration: const InputDecoration(labelText: 'Edad'),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('Todas las edades'),
                      ),
                      DropdownMenuItem(
                        value: 'young',
                        child: Text('Menos de 2 años'),
                      ),
                      DropdownMenuItem(
                        value: 'adult',
                        child: Text('De 2 a 7 años'),
                      ),
                      DropdownMenuItem(
                        value: 'senior',
                        child: Text('8 años o más'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _age = v!),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Ubicación',
                      hintText: 'Ciudad o provincia',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _location = v),
                  ),
                ),
                FilterChip(
                  label: const Text('Mis avisos'),
                  selected: _mine,
                  onSelected: (v) => setState(() => _mine = v),
                ),
              ],
            ),
            const SizedBox(height: 20),
            StreamBuilder<List<Adoption>>(
              stream: _listings,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text(
                    'No se pudieron cargar las adopciones. Revisá las reglas y la conexión.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!
                    .where(
                      (a) =>
                          a.matches(
                            type: _type,
                            age: _age,
                            location: _location,
                          ) &&
                          (!_mine || a.pet.ownerId == widget.user.id),
                    )
                    .toList();
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No hay mascotas con estos filtros. Podés publicar un aviso o cambiar la búsqueda.',
                    ),
                  );
                }
                return LayoutBuilder(
                  builder: (context, size) {
                    final columns = size.maxWidth >= 900
                        ? 3
                        : size.maxWidth >= 580
                        ? 2
                        : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 365,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final a = items[i];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdoptionDetailScreen(
                                  user: widget.user,
                                  adoption: a,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: a.pet.photos.isEmpty
                                      ? const Icon(Icons.pets, size: 76)
                                      : Image.network(
                                          a.pet.photos.first,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const Icon(Icons.pets, size: 76),
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a.pet.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      Text(
                                        '${a.pet.typeLabel} · ${a.pet.age} años',
                                      ),
                                      Text(
                                        a.location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      const Text('Conocer y contactar →'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Alta de aviso a partir de una mascota privada elegida por su propietario.
class PublishAdoptionScreen extends StatefulWidget {
  const PublishAdoptionScreen({required this.user, super.key});
  final AppUser user;
  @override
  State<PublishAdoptionScreen> createState() => _PublishAdoptionScreenState();
}

class _PublishAdoptionScreenState extends State<PublishAdoptionScreen> {
  final _form = GlobalKey<FormState>();
  final _location = TextEditingController();
  final _requirements = TextEditingController();
  String? _pet;
  bool _busy = false;
  String? _error;
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final pet = context.read<PetProvider>().pets.firstWhere(
      (p) => p.id == _pet,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<CommunityService>().publishAdoption(
        Adoption(
          id: '',
          pet: pet,
          ownerName: feedAuthor(context, widget.user).displayName!,
          location: _location.text.trim(),
          requirements: _requirements.text.trim(),
          active: true,
        ),
      );
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo publicar el aviso. Revisá los datos y las reglas.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pets = context
        .watch<PetProvider>()
        .pets
        .where((p) => p.ownerId == widget.user.id)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Publicar adopción')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'El aviso comparte los datos y las fotos de la mascota, tu nombre público y su ubicación. No publica tu email.',
                  ),
                  const SizedBox(height: 16),
                  if (pets.isEmpty)
                    OutlinedButton(
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PetFormScreen(),
                        ),
                      ),
                      child: const Text('Registrar una mascota'),
                    ),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Mascota *'),
                    items: pets
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    onChanged: _busy ? null : (v) => _pet = v,
                    validator: (v) => pets.any((p) => p.id == v)
                        ? null
                        : 'Elegí una mascota propia.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _location,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Ciudad y provincia *',
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? 'Indicá la ubicación.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _requirements,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 1500,
                    decoration: const InputDecoration(
                      labelText: 'Condiciones y cuidados para la adopción',
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy || pets.isEmpty ? null : _save,
                    child: Text(_busy ? 'Publicando…' : 'Publicar aviso'),
                  ),
                  if (_error != null) Text(_error!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _location.dispose();
    _requirements.dispose();
    super.dispose();
  }
}

/// Detalle con formulario de contacto entregado dentro de un chat privado.
class AdoptionDetailScreen extends StatefulWidget {
  const AdoptionDetailScreen({
    required this.user,
    required this.adoption,
    super.key,
  });
  final AppUser user;
  final Adoption adoption;
  @override
  State<AdoptionDetailScreen> createState() => _AdoptionDetailScreenState();
}

class _AdoptionDetailScreenState extends State<AdoptionDetailScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.displayName);
  final _message = TextEditingController();
  bool _busy = false;
  String? _error;
  Future<void> _contact() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final a = widget.adoption;
    try {
      await openConversation(
        context,
        widget.user,
        a.pet.ownerId,
        a.ownerName,
        contactText:
            'Consulta de adopción: ${a.pet.name}\n'
            'Nombre: ${_name.text.trim()}\n${_message.text.trim()}',
      );
      if (mounted) {
        _message.clear();
      }
    } on Object {
      if (mounted) {
        setState(() => _error = 'No se entregó la consulta. Reintentá.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.adoption;
    final own = a.pet.ownerId == widget.user.id;
    return Scaffold(
      appBar: AppBar(title: Text(a.pet.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              for (final url in a.pet.photos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PostMedia(url: url, type: PostMediaType.image),
                ),
              Text(
                a.pet.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                '${a.pet.typeLabel} · ${a.pet.breed} · ${a.pet.age} años · ${a.pet.weight} kg',
              ),
              Text(a.location),
              const SizedBox(height: 16),
              Text(a.pet.bio),
              const SizedBox(height: 16),
              Text('Responsable: ${a.ownerName}'),
              Text(
                a.requirements.isEmpty
                    ? 'Consultá las condiciones al responsable.'
                    : a.requirements,
              ),
              const SizedBox(height: 24),
              if (own)
                FilledButton.tonal(
                  onPressed: _busy
                      ? null
                      : () async {
                          final accepted = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('¿Cerrar el aviso?'),
                              content: const Text(
                                'Dejará de aparecer en la grilla de adopciones.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Cerrar aviso'),
                                ),
                              ],
                            ),
                          );
                          if (accepted != true || !context.mounted) return;
                          setState(() => _busy = true);
                          try {
                            await context
                                .read<CommunityService>()
                                .closeAdoption(a.id, widget.user.id);
                            if (context.mounted) Navigator.pop(context);
                          } on Object {
                            if (mounted) {
                              setState(
                                () => _error = 'No se pudo cerrar el aviso.',
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: const Text('Cerrar aviso de adopción'),
                )
              else
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Quiero adoptar',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Text(
                        'Tu consulta se enviará al responsable por chat privado. Podrán continuar conversando en Mensajes.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _name,
                        maxLength: 120,
                        decoration: const InputDecoration(
                          labelText: 'Tu nombre *',
                        ),
                        validator: (v) => (v?.trim().length ?? 0) < 2
                            ? 'Ingresá tu nombre.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _message,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 1500,
                        decoration: const InputDecoration(
                          labelText: 'Contanos por qué querés adoptar *',
                        ),
                        validator: (v) => (v?.trim().length ?? 0) < 5
                            ? 'Escribí una consulta de al menos 5 caracteres.'
                            : null,
                      ),
                      FilledButton(
                        onPressed: _busy ? null : _contact,
                        child: Text(_busy ? 'Enviando…' : 'Enviar consulta'),
                      ),
                    ],
                  ),
                ),
              if (_error != null) Text(_error!),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _message.dispose();
    super.dispose();
  }
}
