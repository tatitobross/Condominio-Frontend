// Pantallas y componentes de la aplicación de condominio.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/api_service.dart';

class CondominioApp extends StatelessWidget {
  const CondominioApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Condominio',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff315d8f)),
          useMaterial3: true,
        ),
        home: const LoginPage(),
      );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool hidden = true;
  String? error;

  Future<void> login() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await http.post(Uri.parse('$apiBaseUrl/login'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username.text.trim(),
          'password': password.text,
          'device_name': 'condominio-flutter',
        }),
      );
      final data = jsonDecode(response.body.isEmpty ? '{}' : response.body);
      final status = response.statusCode;
      if (status < 200 || status >= 300 || data['token'] == null) {
        throw ApiException(errorText(data));
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(
            token: data['token'].toString(),
            user: Map<String, dynamic>.from(data['user'] as Map),
          ),
        ),
      );
    } on http.ClientException {
      setState(() => error = 'No se pudo conectar con Laravel. Inicia el servidor en el puerto 8000.');
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'No se pudo iniciar sesión.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.apartment_rounded,
                            size: 68, color: Color(0xff315d8f)),
                        const SizedBox(height: 12),
                        Text('Condominio',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 6),
                        const Text('Control residencial y seguridad',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: username,
                          decoration: const InputDecoration(
                              labelText: 'Usuario',
                              prefixIcon: Icon(Icons.person_outline)),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Ingrese su usuario'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: password,
                          obscureText: hidden,
                          onFieldSubmitted: (_) => login(),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(hidden
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => hidden = !hidden),
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Ingrese su contraseña'
                              : null,
                        ),
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Text(error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red)),
                          ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: loading ? null : login,
                          icon: const Icon(Icons.login),
                          label: Text(loading ? 'Ingresando...' : 'Iniciar sesión'),
                        ),
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

enum Module { homes, residents, visits, payments, incidents }

class MenuOption {
  const MenuOption(this.title, this.icon, this.module);
  final String title;
  final IconData icon;
  final Module? module;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.token, required this.user});
  final String token;
  final Map<String, dynamic> user;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Api api = Api(widget.token);
  int selected = 0;

  String get role => ((widget.user['role'] as Map?)?['role'] ?? '').toString();
  bool get admin => role.toLowerCase() == 'administrador';
  bool get resident => role.toLowerCase() == 'residente';
  bool get guard => role.toLowerCase() == 'guardia';

  List<MenuOption> get options {
    final result = <MenuOption>[];
    if (admin) {
      result.add(const MenuOption('Dashboard', Icons.dashboard_outlined, null));
      result.addAll(const [
        MenuOption('Viviendas', Icons.home_work_outlined, Module.homes),
        MenuOption('Residentes', Icons.people_outline, Module.residents),
        MenuOption('Visitas', Icons.badge_outlined, Module.visits),
        MenuOption('Pagos', Icons.payments_outlined, Module.payments),
        MenuOption('Incidencias', Icons.report_problem_outlined, Module.incidents),
      ]);
    } else if (resident) {
      result.addAll(const [
        MenuOption('Visitas', Icons.badge_outlined, Module.visits),
      ]);
    } else if (guard) {
      result.addAll(const [
        MenuOption('Visitas', Icons.badge_outlined, Module.visits),
      ]);
    }
    return result;
  }

  Future<void> logout() async {
    try {
      await api.call('/logout', method: 'POST');
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final option = options[selected];
    return Scaffold(
      appBar: AppBar(title: Text(option.title)),
      drawer: Drawer(
        child: SafeArea(
          child: Column(children: [
            UserAccountsDrawerHeader(
              accountName: Text(widget.user['name']?.toString() ??
                  widget.user['username']?.toString() ??
                  'Usuario'),
              accountEmail: Text('${role.isEmpty ? 'Sin rol' : role} · ${widget.user['email'] ?? ''}'),
              currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: options.length,
                itemBuilder: (_, index) => ListTile(
                  selected: index == selected,
                  leading: Icon(options[index].icon),
                  title: Text(options[index].title),
                  onTap: () {
                    setState(() => selected = index);
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Mi perfil'),
              onTap: () {
                Navigator.pop(context);
                showProfile(context, api, widget.user);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: logout,
            ),
          ]),
        ),
      ),
      body: option.module == null
          ? Dashboard(api: api, user: widget.user, role: role)
          : ModulePage(
              key: ValueKey(option.module),
              api: api,
              module: option.module!,
              isAdmin: admin,
              isResident: resident,
              isGuard: guard,
            ),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, required this.api, required this.user, required this.role});
  final Api api;
  final Map<String, dynamic> user;
  final String role;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  Map<String, dynamic>? metrics;
  String? error;
  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final response = await widget.api.call('/dashboard');
      if (mounted) setState(() => metrics = Map<String, dynamic>.from(response as Map));
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (metrics == null && error == null) return const Center(child: CircularProgressIndicator());
    if (error != null) return Retry(message: error!, onRetry: load);
    final cards = <Metric>[
      Metric('Viviendas activas', metrics!['homes'], Icons.home_work_outlined, Colors.blue),
      Metric('Cuotas pendientes', metrics!['pending_payments'], Icons.payments_outlined, Colors.orange),
      Metric('Incidencias abiertas', metrics!['open_incidents'], Icons.report_problem_outlined, Colors.red),
      Metric('Visitas de hoy', metrics!['visits_today'], Icons.badge_outlined, Colors.green),
    ];
    final name = widget.user['name'] ?? widget.user['username'] ?? 'usuario';
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('Hola, $name', style: Theme.of(context).textTheme.headlineSmall),
        Text('Rol: ${widget.role}'),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards.map((card) => Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(card.icon, color: card.color),
                const Spacer(),
                Text('${card.value ?? 0}', style: Theme.of(context).textTheme.headlineMedium),
                Text(card.label),
              ]),
            ),
          )).toList(),
        ),
        const SizedBox(height: 20),
        const Text('Desliza hacia abajo para actualizar los indicadores.'),
      ]),
    );
  }
}

class Metric {
  const Metric(this.label, this.value, this.icon, this.color);
  final String label;
  final dynamic value;
  final IconData icon;
  final Color color;
}

class FieldSpec {
  const FieldSpec(this.name, this.label,
      {this.required = false, this.numeric = false, this.multiline = false, this.hint});
  final String name;
  final String label;
  final bool required;
  final bool numeric;
  final bool multiline;
  final String? hint;
}

class ModuleInfo {
  const ModuleInfo(this.title, this.path, this.icon, this.fields, this.main, this.detail);
  final String title;
  final String path;
  final IconData icon;
  final List<FieldSpec> fields;
  final String Function(Map<String, dynamic>) main;
  final String Function(Map<String, dynamic>) detail;
}

String field(Map<String, dynamic>? item, String key, [String fallback = '—']) {
  final value = item?[key];
  return value == null || value.toString().isEmpty ? fallback : value.toString();
}

Map<String, dynamic>? mapField(Map<String, dynamic> item, String key) =>
    item[key] is Map ? Map<String, dynamic>.from(item[key] as Map) : null;

final infos = <Module, ModuleInfo>{
  Module.homes: ModuleInfo('Viviendas', '/homes', Icons.home_work_outlined, const [
    FieldSpec('code', 'Código', required: true, hint: 'A-101'),
    FieldSpec('block', 'Bloque / sector'),
    FieldSpec('address', 'Dirección', required: true),
    FieldSpec('status', 'Estado: active o inactive', required: true, hint: 'active'),
  ], (x) => 'Vivienda ${field(x, 'code')}', (x) => '${field(x, 'block', 'Sin bloque')} · ${statusText(field(x, 'status'))}'),
  Module.residents: ModuleInfo('Residentes', '/residents', Icons.people_outline, const [
    FieldSpec('home_id', 'Vivienda', required: true, numeric: true),
    FieldSpec('name', 'Nombre completo', required: true),
    FieldSpec('dpi', 'DPI / documento'),
    FieldSpec('phone', 'Teléfono'),
    FieldSpec('email', 'Correo'),
    FieldSpec('status', 'Estado: active o inactive', required: true, hint: 'active'),
  ], (x) => field(x, 'name'), (x) => '${field(mapField(x, 'home'), 'code', 'Sin vivienda')} · ${field(x, 'phone', 'Sin teléfono')}'),
  Module.visits: ModuleInfo('Visitas', '/visits', Icons.badge_outlined, const [
    FieldSpec('home_id', 'Vivienda', required: true, numeric: true),
    FieldSpec('resident_id', 'Residente', numeric: true),
    FieldSpec('visitor_name', 'Nombre del visitante', required: true),
    FieldSpec('visitor_dpi', 'DPI del visitante'),
    FieldSpec('vehicle_plate', 'Placa del vehículo'),
    FieldSpec('scheduled_at', 'Fecha programada', required: true, hint: '2026-10-15 14:30'),
    FieldSpec('status', 'Estado', hint: 'pending'),
  ], (x) => field(x, 'visitor_name'), (x) => '${field(mapField(x, 'home'), 'code', 'Sin vivienda')} · ${statusText(field(x, 'status'))}'),
  Module.payments: ModuleInfo('Pagos', '/payments', Icons.payments_outlined, const [
    FieldSpec('home_id', 'Vivienda', required: true, numeric: true),
    FieldSpec('period', 'Período', required: true, hint: '2026-10'),
    FieldSpec('due_date', 'Fecha límite', required: true, hint: '2026-10-30'),
    FieldSpec('amount', 'Monto (L)', required: true, numeric: true),
    FieldSpec('reference', 'Referencia'),
    FieldSpec('status', 'Estado', hint: 'pending'),
  ], (x) => 'L ${field(x, 'amount')}', (x) => '${field(mapField(x, 'home'), 'code', 'Sin vivienda')} · ${field(x, 'period')} · ${statusText(field(x, 'status'))}'),
  Module.incidents: ModuleInfo('Incidencias', '/incidents', Icons.report_problem_outlined, const [
    FieldSpec('home_id', 'Vivienda', numeric: true),
    FieldSpec('title', 'Título', required: true),
    FieldSpec('description', 'Descripción', required: true, multiline: true),
    FieldSpec('priority', 'Prioridad: low, medium o high', required: true, hint: 'medium'),
    FieldSpec('status', 'Estado', hint: 'open'),
  ], (x) => field(x, 'title'), (x) => '${field(mapField(x, 'home'), 'code', 'General')} · ${statusText(field(x, 'status'))}'),
};

class ModulePage extends StatefulWidget {
  const ModulePage({super.key, required this.api, required this.module, required this.isAdmin, required this.isResident, required this.isGuard});
  final Api api;
  final Module module;
  final bool isAdmin;
  final bool isResident;
  final bool isGuard;
  @override
  State<ModulePage> createState() => _ModulePageState();
}

class _ModulePageState extends State<ModulePage> {
  final search = TextEditingController();
  List<Map<String, dynamic>> items = [];
  String? error;
  bool loading = true;
  ModuleInfo get info => infos[widget.module]!;

  @override
  void initState() { super.initState(); load(); }
  @override
  void dispose() { search.dispose(); super.dispose(); }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final response = await widget.api.call('${info.path}?search=${Uri.encodeQueryComponent(search.text.trim())}');
      final raw = response is Map && response['data'] is List ? response['data'] as List : <dynamic>[];
      if (mounted) setState(() => items = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList());
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void notice(String message, [bool bad = false]) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: bad ? Colors.red : null));

  Future<void> details(Map<String, dynamic> item) async {
    try {
      final response = await widget.api.call('${info.path}/${item['id']}');
      final record = response is Map && response['data'] is Map ? Map<String, dynamic>.from(response['data'] as Map) : item;
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => AlertDialog(title: Text(info.main(record)), content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: detailRows(record).map((text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text))).toList()))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))]));
    } on ApiException catch (e) { notice(e.message, true); }
  }

  Future<void> edit([Map<String, dynamic>? item]) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => EditDialog(api: widget.api, info: info, item: item));
    if (saved == true) load();
  }

  Future<void> remove(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Eliminar registro'), content: Text('¿Deseas eliminar ${info.main(item)}?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar'))]));
    if (ok != true) return;
    try { await widget.api.call('${info.path}/${item['id']}', method: 'DELETE'); notice('Registro eliminado.'); load(); } on ApiException catch (e) { notice(e.message, true); }
  }

  Future<void> action(Map<String, dynamic> item, String command, String label) async {
    try {
      final response = await widget.api.call('${info.path}/${item['id']}/$command', method: 'POST');
      notice('$label realizado correctamente.');
      load();
      if (command == 'pay' && response is Map && response['invoice'] is Map && mounted) await showPaymentInvoice(context, Map<String, dynamic>.from(response['invoice'] as Map));
    } on ApiException catch (e) { notice(e.message, true); }
  }

  List<Widget> actions(Map<String, dynamic> item) {
    final result = <Widget>[IconButton(tooltip: 'Ver detalle', icon: const Icon(Icons.visibility_outlined), onPressed: () => details(item))];
    if (widget.isAdmin) {
      result.add(IconButton(tooltip: 'Editar', icon: const Icon(Icons.edit_outlined), onPressed: () => edit(item)));
      result.add(IconButton(tooltip: 'Eliminar', icon: const Icon(Icons.delete_outline), onPressed: () => remove(item)));
    }
    if (widget.module == Module.visits) {
      final status = field(item, 'status');
      if ((widget.isAdmin || widget.isResident) && status == 'pending') result.add(IconButton(tooltip: 'Autorizar', icon: const Icon(Icons.verified_outlined), onPressed: () => action(item, 'authorize', 'Autorización')));
      if ((widget.isAdmin || widget.isGuard) && status == 'authorized') result.add(IconButton(tooltip: 'Registrar entrada', icon: const Icon(Icons.login), onPressed: () => action(item, 'entry', 'Entrada')));
      if ((widget.isAdmin || widget.isGuard) && status == 'entered') result.add(IconButton(tooltip: 'Registrar salida', icon: const Icon(Icons.logout), onPressed: () => action(item, 'exit', 'Salida')));
    }
    if (widget.module == Module.payments && widget.isAdmin && field(item, 'status') != 'paid') result.add(IconButton(tooltip: 'Registrar pago', icon: const Icon(Icons.check_circle_outline), onPressed: () => action(item, 'pay', 'Pago')));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Retry(message: error!, onRetry: load);
    return Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Row(children: [
        Expanded(child: TextField(controller: search, onSubmitted: (_) => load(), decoration: InputDecoration(labelText: 'Buscar ${info.title.toLowerCase()}', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: load)))),
        if (widget.isAdmin || (widget.isResident && widget.module == Module.visits)) ...[
          const SizedBox(width: 10),
          FilledButton.icon(onPressed: () => edit(), icon: const Icon(Icons.add), label: const Text('Nuevo')),
        ],
      ])),
      Expanded(child: RefreshIndicator(onRefresh: load, child: items.isEmpty ? ListView(children: [const SizedBox(height: 190), Center(child: Text('No hay ${info.title.toLowerCase()} registrados.'))]) : ListView.separated(itemCount: items.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, index) { final item = items[index]; return ListTile(leading: CircleAvatar(child: Icon(info.icon)), title: Text(info.main(item)), subtitle: Text(info.detail(item)), onTap: () => details(item), trailing: Wrap(children: actions(item))); })),
      ),
    ]);
  }
}

Future<void> showPaymentInvoice(BuildContext context, Map<String, dynamic> invoice) => showDialog<void>(
  context: context,
  builder: (_) => AlertDialog(
    title: Row(children: const [Icon(Icons.receipt_long, color: Color(0xff315d8f)), SizedBox(width: 10), Text('Recibo de pago')]),
    content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('No. ${field(invoice, 'number')}', style: const TextStyle(fontWeight: FontWeight.bold)),
      const Divider(height: 26),
      Text('Vivienda: ${field(mapField(invoice, 'home'), 'code')}'),
      Text('Período: ${field(invoice, 'period')}'),
      Text('Referencia: ${field(invoice, 'reference', '—')}'),
      const SizedBox(height: 12),
      Text('TOTAL PAGADO: L ${field(invoice, 'amount', '0.00')}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    ])),
    actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Listo'))],
  ),
);

class EditDialog extends StatefulWidget {
  const EditDialog({super.key, required this.api, required this.info, this.item});
  final Api api;
  final ModuleInfo info;
  final Map<String, dynamic>? item;
  @override
  State<EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<EditDialog> {
  final form = GlobalKey<FormState>();
  final controllers = <String, TextEditingController>{};
  List<Map<String, dynamic>> homes = [];
  List<Map<String, dynamic>> residents = [];
  String? error;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    for (final spec in widget.info.fields) {
      controllers[spec.name] = TextEditingController(text: widget.item?[spec.name]?.toString() ?? defaultValue(widget.info.path, spec.name));
    }
    _loadRelations();
  }

  bool get needsHomes => widget.info.fields.any((spec) => spec.name == 'home_id');
  bool get needsResidents => widget.info.fields.any((spec) => spec.name == 'resident_id');

  List<Map<String, dynamic>> _records(dynamic response) {
    final data = response is Map && response['data'] is List ? response['data'] as List : const <dynamic>[];
    return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Future<void> _loadRelations() async {
    try {
      final results = await Future.wait<dynamic>([
        if (needsHomes) widget.api.call('/homes'),
        if (needsResidents) widget.api.call('/residents'),
      ]);
      if (!mounted) return;
      var position = 0;
      setState(() {
        if (needsHomes) homes = _records(results[position++]);
        if (needsResidents) residents = _records(results[position++]);
      });
    } catch (_) {
      // El formulario conserva la entrada manual si no se pueden cargar catálogos.
    }
  }

  String? _selectedId(TextEditingController controller, List<Map<String, dynamic>> options) {
    final value = controller.text;
    return options.any((item) => item['id']?.toString() == value) ? value : null;
  }

  List<Map<String, dynamic>> get availableResidents {
    final homeId = controllers['home_id']?.text;
    if (homeId == null || homeId.isEmpty) return residents;
    return residents.where((resident) => resident['home_id']?.toString() == homeId).toList();
  }

  String homeName(Map<String, dynamic> home) {
    final code = field(home, 'code', 'Sin código');
    final address = field(home, 'address');
    return address.isEmpty ? code : '$code · $address';
  }

  String residentName(Map<String, dynamic> resident) {
    final name = field(resident, 'name', 'Sin nombre');
    final home = mapField(resident, 'home');
    final code = home == null ? '' : field(home, 'code');
    return code.isEmpty ? name : '$name · $code';
  }

  @override
  void dispose() { for (final c in controllers.values) { c.dispose(); } super.dispose(); }

  Future<void> save() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() { saving = true; error = null; });
    final data = <String, dynamic>{};
    for (final spec in widget.info.fields) {
      final text = controllers[spec.name]!.text.trim();
      if (text.isNotEmpty) data[spec.name] = spec.numeric ? num.tryParse(text) ?? text : text;
    }
    try {
      await widget.api.call(widget.item == null ? widget.info.path : '${widget.info.path}/${widget.item!['id']}', method: widget.item == null ? 'POST' : 'PUT', body: data);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally { if (mounted) setState(() => saving = false); }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.item == null ? 'Nuevo registro' : 'Editar registro'),
    content: SizedBox(width: 500, child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      for (final spec in widget.info.fields)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: spec.name == 'home_id' && homes.isNotEmpty
              ? DropdownButtonFormField<String>(
                  value: _selectedId(controllers[spec.name]!, homes),
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Vivienda'),
                  items: homes.map((home) => DropdownMenuItem(value: home['id'].toString(), child: Text(homeName(home), overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (value) => setState(() {
                    controllers[spec.name]!.text = value ?? '';
                    final resident = controllers['resident_id'];
                    if (resident != null && !availableResidents.any((item) => item['id']?.toString() == resident.text)) resident.text = '';
                  }),
                  validator: (value) => spec.required && (value == null || value.isEmpty) ? 'Seleccione una vivienda' : null,
                )
              : spec.name == 'resident_id' && residents.isNotEmpty
                  ? DropdownButtonFormField<String>(
                      value: _selectedId(controllers[spec.name]!, availableResidents),
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Residente'),
                      hint: availableResidents.isEmpty ? const Text('No hay residentes en esta vivienda') : null,
                      items: availableResidents.map((resident) => DropdownMenuItem(value: resident['id'].toString(), child: Text(residentName(resident), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: availableResidents.isEmpty ? null : (value) => setState(() => controllers[spec.name]!.text = value ?? ''),
                    )
                  : spec.name == 'status'
              ? DropdownButtonFormField<String>(
                  value: controllers[spec.name]!.text.isEmpty ? null : controllers[spec.name]!.text,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: statusOptions(widget.info.path).map((value) => DropdownMenuItem(value: value, child: Text(statusText(value)))).toList(),
                  onChanged: (value) => setState(() => controllers[spec.name]!.text = value ?? ''),
                )
              : spec.name == 'priority'
                  ? DropdownButtonFormField<String>(
                      value: controllers[spec.name]!.text.isEmpty ? null : controllers[spec.name]!.text,
                      decoration: const InputDecoration(labelText: 'Prioridad'),
                      items: const [DropdownMenuItem(value: 'low', child: Text('Baja')), DropdownMenuItem(value: 'medium', child: Text('Media')), DropdownMenuItem(value: 'high', child: Text('Alta'))],
                      onChanged: (value) => setState(() => controllers[spec.name]!.text = value ?? ''),
                    )
                  : TextFormField(
                      controller: controllers[spec.name],
                      keyboardType: spec.numeric ? TextInputType.number : TextInputType.text,
                      minLines: spec.multiline ? 3 : 1,
                      maxLines: spec.multiline ? 5 : 1,
                      decoration: InputDecoration(
                        labelText: spec.label,
                        hintText: spec.hint,
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (spec.required && value.isEmpty) return 'Este campo es obligatorio';
                        if (spec.name == 'home_id' && value.isNotEmpty && int.tryParse(value) == null) return 'Seleccione una vivienda válida';
                        if (spec.name == 'resident_id' && value.isNotEmpty && int.tryParse(value) == null) return 'Seleccione un residente válido';
                        if (spec.name == 'email' && value.isNotEmpty && !value.contains('@')) return 'Ingrese un correo válido, por ejemplo: nombre@correo.com';
                        if (spec.name == 'scheduled_at' && value.isNotEmpty && DateTime.tryParse(value.replaceFirst(' ', 'T')) == null) return 'Use fecha y hora: 2026-10-15 14:30';
                        return null;
                      },
                    ),
        ),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
    ])))),
    actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')), FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Guardando...' : 'Guardar'))],
  );
}

String defaultValue(String path, String name) {
  if (name == 'status') {
    if (path == '/homes' || path == '/residents') return 'active';
    if (path == '/visits' || path == '/payments') return 'pending';
    if (path == '/incidents') return 'open';
  }
  return '';
}

List<String> statusOptions(String path) {
  if (path == '/homes' || path == '/residents') return ['active', 'inactive'];
  if (path == '/visits') return ['pending', 'authorized', 'entered', 'exited', 'rejected'];
  if (path == '/payments') return ['pending', 'paid', 'overdue'];
  if (path == '/incidents') return ['open', 'in_progress', 'resolved'];
  return const [];
}

String pretty(String key) => key.replaceAll('_', ' ').replaceFirst(key[0], key[0].toUpperCase());
String display(dynamic value) => value is Map || value is List ? jsonEncode(value) : value.toString();

String statusText(String value) => {
  'active': 'Activo', 'inactive': 'Inactivo', 'pending': 'Pendiente',
  'authorized': 'Autorizada', 'entered': 'En curso', 'exited': 'Finalizada',
  'rejected': 'Rechazada', 'paid': 'Pagado', 'overdue': 'Vencido',
  'open': 'Abierta', 'in_progress': 'En proceso', 'resolved': 'Resuelta',
}[value] ?? value;

String labelText(String key) => {
  'code': 'Código', 'block': 'Bloque / sector', 'address': 'Dirección',
  'name': 'Nombre completo', 'dpi': 'DPI / documento', 'phone': 'Teléfono',
  'email': 'Correo', 'visitor_name': 'Visitante', 'visitor_dpi': 'DPI del visitante',
  'vehicle_plate': 'Placa', 'scheduled_at': 'Fecha programada', 'period': 'Período',
  'due_date': 'Fecha límite', 'amount': 'Monto', 'reference': 'Referencia',
  'title': 'Título', 'description': 'Descripción', 'priority': 'Prioridad', 'status': 'Estado',
}[key] ?? pretty(key);

List<String> detailRows(Map<String, dynamic> record) {
  const hidden = {'id', 'home_id', 'resident_id', 'reported_by', 'created_at', 'updated_at', 'home', 'resident', 'reporter'};
  final rows = <String>[];
  for (final entry in record.entries) {
    if (hidden.contains(entry.key) || entry.value == null) continue;
    var value = entry.value.toString();
    if (entry.key == 'status') value = statusText(value);
    if (entry.key == 'priority') value = {'low': 'Baja', 'medium': 'Media', 'high': 'Alta'}[value] ?? value;
    rows.add('${labelText(entry.key)}: $value');
  }
  final home = mapField(record, 'home');
  final resident = mapField(record, 'resident');
  final reporter = mapField(record, 'reporter');
  if (home != null) rows.add('Vivienda: ${field(home, 'code')}');
  if (resident != null) rows.add('Residente: ${field(resident, 'name')}');
  if (reporter != null) rows.add('Reportado por: ${field(reporter, 'name')}');
  return rows;
}

class Retry extends StatelessWidget {
  const Retry({super.key, required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 48, color: Colors.red), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar'))])));
}

Future<void> showProfile(BuildContext context, Api api, Map<String, dynamic> user) async {
  final name = TextEditingController(text: user['name']?.toString() ?? '');
  final email = TextEditingController(text: user['email']?.toString() ?? '');
  String? error;
  bool saving = false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (_, setDialog) => AlertDialog(
        title: const Text('Mi perfil'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 12),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Correo')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: Colors.red))),
          ]),
        ),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: saving ? null : () async {
              setDialog(() { saving = true; error = null; });
              try {
                await api.call('/profile', method: 'PUT', body: {'name': name.text.trim(), 'email': email.text.trim()});
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } on ApiException catch (e) {
                if (dialogContext.mounted) setDialog(() { saving = false; error = e.message; });
              }
            },
            child: Text(saving ? 'Guardando...' : 'Guardar'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  email.dispose();
}
