import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeLab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4F8CFF),
          surface: Color(0xFF171A23),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class ServerConfig {
  static const _key = 'server_url';
  static Future<String> load() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_key) ?? 'http://192.168.0.110:8086';
  }

  static Future<void> save(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, url);
  }
}

class ServiceInfo {
  final String name;
  final int port;
  final String icon;
  final String desc;
  final String path;
  final bool online;
  final int code;

  ServiceInfo({
    required this.name,
    required this.port,
    required this.icon,
    required this.desc,
    required this.path,
    required this.online,
    required this.code,
  });

  factory ServiceInfo.fromJson(Map<String, dynamic> j) => ServiceInfo(
        name: j['name'] ?? '?',
        port: (j['port'] as num).toInt(),
        icon: j['icon'] ?? '🖥️',
        desc: j['desc'] ?? '',
        path: j['path'] ?? '/',
        online: j['online'] == true,
        code: (j['code'] as num).toInt(),
      );
}

class SystemInfo {
  final int cpuPercent;
  final int memPercent;
  final double memUsed;
  final double memTotal;
  final int uptime;
  final String hostname;

  SystemInfo({
    required this.cpuPercent,
    required this.memPercent,
    required this.memUsed,
    required this.memTotal,
    required this.uptime,
    required this.hostname,
  });

  factory SystemInfo.fromJson(Map<String, dynamic> j) => SystemInfo(
        cpuPercent: (j['cpuPercent'] as num).toInt(),
        memPercent: (j['memPercent'] as num).toInt(),
        memUsed: (j['memUsed'] as num).toDouble(),
        memTotal: (j['memTotal'] as num).toDouble(),
        uptime: (j['uptime'] as num).toInt(),
        hostname: j['hostname'] ?? '',
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _serverUrl = '';
  List<ServiceInfo> _services = [];
  SystemInfo? _system;
  bool _loading = true;
  String? _error;
  final TextEditingController _search = TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _serverUrl = await ServerConfig.load();
    await _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_serverUrl.isEmpty) return;
    try {
      final res = await http
          .get(Uri.parse('$_serverUrl/api/status'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final d = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _services = (d['services'] as List)
            .map((e) => ServiceInfo.fromJson(e as Map<String, dynamic>))
            .toList();
        _system = SystemInfo.fromJson(d['system'] as Map<String, dynamic>);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!silent) {
        setState(() {
          _loading = false;
          _error = 'Не удалось подключиться к серверу\n$_serverUrl\n\n'
              'Детали: $e\n\n'
              'Проверь адрес в настройках (⚙).\n'
              'С ПК должно быть доступно: Test-NetConnection ${Uri.parse(_serverUrl).host} -Port ${Uri.parse(_serverUrl).port}';
        });
      }
    }
  }

  Future<void> _editServer() async {
    final controller = TextEditingController(text: _serverUrl);
    final newUrl = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Адрес сервера'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'http://192.168.0.110:8086',
            helperText: 'Домашний IP или Tailscale-адрес',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (newUrl != null && newUrl.isNotEmpty) {
      await ServerConfig.save(newUrl);
      setState(() {
        _serverUrl = newUrl;
        _loading = true;
        _error = null;
      });
      await _refresh();
    }
  }

  String _fmtUptime(int sec) {
    final d = sec ~/ 86400, h = (sec % 86400) ~/ 3600, m = (sec % 3600) ~/ 60;
    if (d > 0) return '$d д $h ч';
    if (h > 0) return '$h ч $m мин';
    return '$m мин';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🖥️'),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_system?.hostname.isNotEmpty == true ? _system!.hostname : 'HomeLab',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (_system != null)
                  Text('аптайм ${_fmtUptime(_system!.uptime)}',
                      style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _refresh()),
          IconButton(icon: const Icon(Icons.settings), onPressed: _editServer),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.cloud_off, size: 56, color: Colors.white38),
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_system != null) _systemCard(),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Поиск по сервисам…',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: const Color(0xFF171A23),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _servicesGrid(),
      ],
    );
  }

  Widget _systemCard() {
    final s = _system!;
    return Card(
      color: const Color(0xFF171A23),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _meter('CPU', s.cpuPercent, Colors.lightBlue)),
            const SizedBox(width: 12),
            Expanded(
              child: _meter('RAM', s.memPercent, Colors.greenAccent,
                  label: '${s.memUsed.toStringAsFixed(1)}/${s.memTotal.toStringAsFixed(1)} ГБ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meter(String title, int percent, Color color, {String? label}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontSize: 13, color: Colors.white70)),
            const Spacer(),
            Text(label ?? '$percent%', style: const TextStyle(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 8,
            backgroundColor: const Color(0xFF262B3D),
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _servicesGrid() {
    final q = _search.text.toLowerCase();
    final list = _services.where((s) =>
        s.name.toLowerCase().contains(q) || s.desc.toLowerCase().contains(q)).toList();
    if (list.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: Text('Ничего не найдено', style: TextStyle(color: Colors.white54))),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _serviceCard(list[i]),
    );
  }

  Widget _serviceCard(ServiceInfo s) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceViewerPage(
        serverUrl: _serverUrl, service: s,
      ))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF171A23),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF21263A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(s.icon, style: const TextStyle(fontSize: 24)),
                const Spacer(),
                Container(
                  width: 9, height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: s.online ? const Color(0xFF3DDC84) : const Color(0xFFFF5252),
                    boxShadow: [
                      BoxShadow(
                        color: (s.online ? const Color(0xFF3DDC84) : const Color(0xFFFF5252)).withOpacity(.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(s.desc, style: const TextStyle(fontSize: 11, color: Colors.white54),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(s.online ? 'работает' : (s.code == 0 ? 'не отвечает' : 'ошибка ${s.code}'),
                    style: TextStyle(
                      fontSize: 11,
                      color: s.online ? const Color(0xFF3DDC84) : const Color(0xFFFF5252),
                    )),
                const Spacer(),
                Text(':${s.port}', style: const TextStyle(fontSize: 11, color: Colors.white38)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceViewerPage extends StatefulWidget {
  final String serverUrl;
  final ServiceInfo service;

  const ServiceViewerPage({super.key, required this.serverUrl, required this.service});

  @override
  State<ServiceViewerPage> createState() => _ServiceViewerPageState();
}

class _ServiceViewerPageState extends State<ServiceViewerPage> {
  late InAppWebViewController _controller;
  bool _loading = true;
  String _currentUrl = '';

  Uri get _targetUri {
    final base = Uri.parse(widget.serverUrl);
    final host = base.host;
    final scheme = base.scheme;
    return Uri.parse('$scheme://$host:${widget.service.port}${widget.service.path}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('${widget.service.icon} ${widget.service.name}'),
        actions: [
          if (_currentUrl.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => launchUrl(Uri.parse(_currentUrl), mode: LaunchMode.externalApplication),
            ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_targetUri.toString())),
            onWebViewCreated: (c) => _controller = c,
            onLoadStop: (c, url) {
              setState(() {
                _loading = false;
                _currentUrl = url?.toString() ?? '';
              });
            },
            onReceivedError: (c, req, err) {
              setState(() => _loading = false);
            },
            onLoadError: (c, url, code, msg) {
              setState(() => _loading = false);
            },
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}
