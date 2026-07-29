import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/image_bytes_picker.dart';
import '../../../core/utils/maps_url.dart';
import '../../../core/di/providers.dart';
import '../../../domain/entities/microbusiness.dart';
import '../../../services/laravel_api_service.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/category_viewmodel.dart';
import '../../viewmodels/microbusiness_viewmodel.dart';
import '../../widgets/app_scaffold.dart';

class MicrobusinessFormScreen extends ConsumerStatefulWidget {
  const MicrobusinessFormScreen({
    super.key,
    this.businessId,
    this.onboardingRequired = false,
  });

  final String? businessId;
  final bool onboardingRequired;

  @override
  ConsumerState<MicrobusinessFormScreen> createState() =>
      _MicrobusinessFormScreenState();
}

class _MicrobusinessFormScreenState
    extends ConsumerState<MicrobusinessFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _mapsUrlCtrl = TextEditingController();
  final _contactoCtrl = TextEditingController();
  final _horarioCtrl = TextEditingController();
  final Map<String, TextEditingController> _fieldControllers = {};

  String _categoria = defaultMicrobusinessCategories.first.nombre;
  MicrobusinessStatus _estado = MicrobusinessStatus.activo;
  String? _loadedBusinessId;
  String _imageUrl = '';
  Uint8List? _pendingImageBytes;
  String? _pendingImageFileName;
  final String _draftBusinessId =
      'micro_${DateTime.now().millisecondsSinceEpoch}';
  bool _isUploadingImage = false;

  bool get _isEditing => widget.businessId != null;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _direccionCtrl.dispose();
    _mapsUrlCtrl.dispose();
    _contactoCtrl.dispose();
    _horarioCtrl.dispose();
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerForField(
    MicrobusinessFieldDefinition field, {
    String initialValue = '',
  }) {
    return _fieldControllers.putIfAbsent(
      field.id,
      () => TextEditingController(text: initialValue),
    );
  }

  void _syncEditingState(List<Microbusiness> businesses) {
    final id = widget.businessId;
    if (id == null || _loadedBusinessId == id) return;

    final matches = businesses.where((item) => item.id == id);
    if (matches.isEmpty) return;

    final business = matches.first;
    _loadedBusinessId = id;
    _nombreCtrl.text = business.nombre;
    _descripcionCtrl.text = business.descripcion;
    _direccionCtrl.text = business.direccion;
    _mapsUrlCtrl.text = business.mapsUrl.isNotEmpty
        ? business.mapsUrl
        : 'https://www.google.com/maps/search/?api=1&query=${business.latitud},${business.longitud}';
    _imageUrl = business.imagen;
    _contactoCtrl.text = business.contacto;
    _horarioCtrl.text = business.horario;
    _categoria = business.categoria.isEmpty
        ? defaultMicrobusinessCategories.first.nombre
        : business.categoria;
    for (final entry in business.campos.entries) {
      final controller = _fieldControllers[entry.key];
      if (controller != null) {
        controller.text = entry.value;
      }
    }
    _estado = business.estado;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final authUser = ref.read(authViewModelProvider).user;
    if (authUser == null) return;

    final state = ref.read(microbusinessViewModelProvider);
    final current =
        _isEditing ? _findBusiness(state.businesses, widget.businessId!) : null;
    final parsedLocation = parseGoogleMapsLocation(_mapsUrlCtrl.text);
    final latitude = parsedLocation?.latitude ?? current?.latitud ?? 4.7110;
    final longitude =
        parsedLocation?.longitude ?? current?.longitud ?? -74.0721;
    final customFields = {
      for (final entry in _fieldControllers.entries)
        entry.key: entry.value.text.trim(),
    };

    final businessId = widget.businessId ?? _draftBusinessId;
    final business = Microbusiness(
      id: businessId,
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim(),
      categoria: _categoria,
      direccion: _direccionCtrl.text.trim(),
      latitud: latitude,
      longitud: longitude,
      mapsUrl: _mapsUrlCtrl.text.trim(),
      imagen: _pendingImageBytes == null ? _imageUrl : '',
      propietarioId: current?.propietarioId ?? authUser.uid,
      contacto: _contactoCtrl.text.trim(),
      horario: _horarioCtrl.text.trim(),
      estado: _estado,
      fechaCreacion: current?.fechaCreacion ?? DateTime.now(),
      favoritos: current?.favoritos ?? const [],
      ratingPromedio: current?.ratingPromedio,
      totalCalificaciones: current?.totalCalificaciones,
      campos: customFields,
    );

    final vm = ref.read(microbusinessViewModelProvider.notifier);
    if (_isEditing) {
      await vm.updateBusiness(business);
    } else {
      await vm.createBusiness(business);
    }

    if (!mounted) return;
    final error = ref.read(microbusinessViewModelProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    if (_pendingImageBytes != null) {
      setState(() => _isUploadingImage = true);
      try {
        final saved =
            await ref.read(laravelApiServiceProvider).uploadMicrobusinessImage(
                  businessId: businessId,
                  bytes: _pendingImageBytes!,
                  fileName: _pendingImageFileName ?? 'micronegocio.jpg',
                );
        if (!mounted) return;
        setState(() {
          _imageUrl = (saved['imagen'] ?? '').toString();
          _pendingImageBytes = null;
          _pendingImageFileName = null;
        });
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El micronegocio se guardó, pero no se pudo cargar la imagen: $error',
            ),
          ),
        );
        if (!widget.onboardingRequired) return;
      } finally {
        if (mounted) setState(() => _isUploadingImage = false);
      }
    }

    if (!mounted) return;
    if (widget.onboardingRequired) {
      ref.read(authViewModelProvider.notifier).markMicrobusinessRegistered();
      context.go('/entrepreneur');
    } else {
      context.go('/micronegocios');
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picked = await pickImageBytes();
    if (picked == null) return;

    final safeName =
        picked.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    setState(() {
      _pendingImageBytes = picked.bytes;
      _pendingImageFileName = safeName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(microbusinessViewModelProvider);
    final fieldDefinitionsAsync =
        ref.watch(microbusinessFieldDefinitionsProvider);
    final categories =
        ref.watch(activeMicrobusinessCategoriesProvider).maybeWhen(
              data: (items) => items.isEmpty
                  ? defaultMicrobusinessCategories
                      .map((category) => category.nombre)
                      .toList()
                  : items.map((category) => category.nombre).toList(),
              orElse: () => defaultMicrobusinessCategories
                  .map((category) => category.nombre)
                  .toList(),
            );
    _syncEditingState(state.businesses);
    if (!categories.contains(_categoria)) {
      _categoria = categories.first;
    }

    return AppScaffold(
      title: widget.onboardingRequired
          ? 'Registra tu micronegocio'
          : _isEditing
              ? 'Editar micronegocio'
              : 'Crear micronegocio',
      showBack: !widget.onboardingRequired,
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            SectionHeader(
              title: _isEditing ? 'Actualizar registro' : 'Nuevo registro',
              subtitle: widget.onboardingRequired
                  ? 'Este paso es obligatorio para completar la creación de tu cuenta.'
                  : 'Completa la información visible en el directorio georreferenciado.',
              icon: Icons.add_business_outlined,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _categoria,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: categories
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ))
                          .toList(),
                      onChanged: (value) => setState(
                        () => _categoria = value ?? categories.first,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descripcionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                      minLines: 2,
                      maxLines: 4,
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _direccionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _mapsUrlCtrl,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'URL de Google Maps',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      validator: _mapsUrlValidator,
                    ),
                    const SizedBox(height: 12),
                    _ImageUploadField(
                      imageUrl: _imageUrl,
                      imageBytes: _pendingImageBytes,
                      isUploading: _isUploadingImage,
                      onPickImage: _pickAndUploadImage,
                      onRemove: _imageUrl.isEmpty && _pendingImageBytes == null
                          ? null
                          : () => setState(() {
                                _imageUrl = '';
                                _pendingImageBytes = null;
                                _pendingImageFileName = null;
                              }),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contacto',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _horarioCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Horario',
                        prefixIcon: Icon(Icons.schedule_outlined),
                      ),
                      validator: _required,
                    ),
                    fieldDefinitionsAsync.when(
                      data: (fields) {
                        if (fields.isEmpty) return const SizedBox.shrink();
                        final current = _isEditing
                            ? _findBusiness(
                                state.businesses, widget.businessId!)
                            : null;
                        return _CustomFieldsSection(
                          fields: fields,
                          values: current?.campos ?? const {},
                          controllerForField: _controllerForField,
                          requiredValidator: _required,
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Micronegocio activo'),
                      value: _estado == MicrobusinessStatus.activo,
                      onChanged: (value) => setState(
                        () => _estado = value
                            ? MicrobusinessStatus.activo
                            : MicrobusinessStatus.inactivo,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed:
                  state.isSubmitting || _isUploadingImage ? null : _submit,
              icon: state.isSubmitting || _isUploadingImage
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isEditing ? 'Guardar cambios' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obligatorio.' : null;

  String? _mapsUrlValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Campo obligatorio.';
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme) return 'Ingresa una URL válida.';
    final host = uri.host.toLowerCase();
    if (!host.contains('google') && !host.contains('goo.gl')) {
      return 'Usa una URL de Google Maps.';
    }
    return null;
  }

  Microbusiness? _findBusiness(List<Microbusiness> businesses, String id) {
    for (final business in businesses) {
      if (business.id == id) return business;
    }
    return null;
  }
}

class _CustomFieldsSection extends StatelessWidget {
  const _CustomFieldsSection({
    required this.fields,
    required this.values,
    required this.controllerForField,
    required this.requiredValidator,
  });

  final List<MicrobusinessFieldDefinition> fields;
  final Map<String, String> values;
  final TextEditingController Function(
    MicrobusinessFieldDefinition field, {
    String initialValue,
  }) controllerForField;
  final String? Function(String? value) requiredValidator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Text(
          'Campos adicionales',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        ...fields.map(
          (field) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CustomFieldInput(
              field: field,
              value: values[field.id] ?? '',
              controllerForField: controllerForField,
              requiredValidator: requiredValidator,
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomFieldInput extends StatefulWidget {
  const _CustomFieldInput({
    required this.field,
    required this.value,
    required this.controllerForField,
    required this.requiredValidator,
  });

  final MicrobusinessFieldDefinition field;
  final String value;
  final TextEditingController Function(
    MicrobusinessFieldDefinition field, {
    String initialValue,
  }) controllerForField;
  final String? Function(String? value) requiredValidator;

  @override
  State<_CustomFieldInput> createState() => _CustomFieldInputState();
}

class _CustomFieldInputState extends State<_CustomFieldInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controllerForField(
      widget.field,
      initialValue: widget.value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.field;
    final validator = field.isRequired ? widget.requiredValidator : null;

    if (field.fieldType == 'select' && field.options.isNotEmpty) {
      final currentValue =
          field.options.contains(_controller.text) ? _controller.text : null;
      return DropdownButtonFormField<String>(
        initialValue: currentValue,
        decoration: InputDecoration(
          labelText: field.name,
          prefixIcon: const Icon(Icons.tune_outlined),
        ),
        items: field.options
            .map((option) => DropdownMenuItem(
                  value: option,
                  child: Text(option),
                ))
            .toList(),
        onChanged: (value) => _controller.text = value ?? '',
        validator: validator,
      );
    }

    return TextFormField(
      controller: _controller,
      keyboardType: field.fieldType == 'number'
          ? TextInputType.number
          : TextInputType.text,
      minLines: field.fieldType == 'textarea' ? 2 : 1,
      maxLines: field.fieldType == 'textarea' ? 4 : 1,
      decoration: InputDecoration(
        labelText: field.name,
        prefixIcon: const Icon(Icons.tune_outlined),
      ),
      validator: validator,
    );
  }
}

class _ImageUploadField extends StatelessWidget {
  const _ImageUploadField({
    required this.imageUrl,
    required this.imageBytes,
    required this.isUploading,
    required this.onPickImage,
    required this.onRemove,
  });

  final String imageUrl;
  final Uint8List? imageBytes;
  final bool isUploading;
  final VoidCallback onPickImage;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageBytes != null || imageUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: imageBytes != null
                    ? Image.memory(imageBytes!, fit: BoxFit.cover)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isUploading ? null : onPickImage,
                  icon: isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(
                    isUploading
                        ? 'Cargando imagen...'
                        : imageUrl.isEmpty && imageBytes == null
                            ? 'Cargar imagen'
                            : 'Cambiar imagen',
                  ),
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Quitar imagen',
                  onPressed: isUploading ? null : onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
