import 'package:flutter/material.dart';

import 'Library.dart';

// ==================== 6. UI HELPERS ====================
String _fmt(DateTime d) {
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(d.day)}/${p(d.month)} ${p(d.hour)}:${p(d.minute)}';
}

void showToast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
}

/// Bắt lỗi tập trung cho mọi thao tác trên UI
Future<void> runAction(
  BuildContext context,
  Future<String?> Function() action,
) async {
  try {
    final msg = await action();
    if (msg != null && context.mounted) showToast(context, msg);
  } on LibraryException catch (e) {
    if (context.mounted) showToast(context, e.message, error: true);
  } on ArgumentError catch (e) {
    if (context.mounted) showToast(context, '${e.message}', error: true);
  } catch (e) {
    if (context.mounted) showToast(context, 'Lỗi hệ thống: $e', error: true);
  }
}

// ==================== 7. APP ROOT ====================
void main() => runApp(const LibraryApp());

class LibraryApp extends StatefulWidget {
  const LibraryApp({super.key});
  @override
  State<LibraryApp> createState() => _LibraryAppState();
}

class _LibraryAppState extends State<LibraryApp> {
  final _auth = AuthService();
  final _service = LibraryService(BookRepository(), RequestRepository());
  User? _user;

  @override
  void initState() {
    super.initState();
    _service.seed();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quản lý thư viện',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: _user == null
          ? LoginPage(auth: _auth, onLogin: (u) => setState(() => _user = u))
          : HomePage(
              key: ValueKey(_user!.username),
              user: _user!,
              service: _service,
              onLogout: () => setState(() => _user = null),
            ),
    );
  }
}

// ==================== 8. LOGIN ====================
class LoginPage extends StatefulWidget {
  final AuthService auth;
  final ValueChanged<User> onLogin;
  const LoginPage({super.key, required this.auth, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  Role _role = Role.student;
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final user = widget.auth.login(
        _username.text.trim(),
        _password.text,
        _role,
      );
      widget.onLogin(user);
    } on LibraryException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.local_library, size: 64, color: scheme.primary),
                const SizedBox(height: 8),
                Text(
                  'Quản lý thư viện',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                SegmentedButton<Role>(
                  segments: const [
                    ButtonSegment(
                      value: Role.student,
                      label: Text('Sinh viên'),
                      icon: Icon(Icons.school),
                    ),
                    ButtonSegment(
                      value: Role.librarian,
                      label: Text('Quản kho'),
                      icon: Icon(Icons.inventory_2),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() {
                    _role = s.first;
                    _error = null;
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _username,
                  decoration: const InputDecoration(
                    labelText: 'Tài khoản',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: _hide,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _hide ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submit,
                  child: const Text('Đăng nhập'),
                ),
                const SizedBox(height: 24),
                Card(
                  color: scheme.surfaceContainerHighest,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Tài khoản demo:\n'
                      '• Quản kho: admin / admin\n'
                      '• Sinh viên: sv01 / 123  hoặc  sv02 / 123',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== 9. HOME ====================
class HomePage extends StatelessWidget {
  final User user;
  final LibraryService service;
  final VoidCallback onLogout;

  const HomePage({
    super.key,
    required this.user,
    required this.service,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final isLib = user.role == Role.librarian;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('📚 Thư viện'),
          actions: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '${user.name}\n${isLib ? 'Quản kho' : 'Sinh viên'}',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Đăng xuất',
              icon: const Icon(Icons.logout),
              onPressed: onLogout,
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(child: Text('Kho sách')),
              Tab(
                child: ListenableBuilder(
                  listenable: service,
                  builder: (_, __) {
                    if (!isLib) return const Text('Yêu cầu của tôi');
                    final n = service.pendingCount;
                    return Text(n > 0 ? 'Yêu cầu ($n chờ duyệt)' : 'Yêu cầu');
                  },
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            BookListTab(user: user, service: service),
            RequestsTab(user: user, service: service),
          ],
        ),
      ),
    );
  }
}

// ==================== 10. TAB: KHO SÁCH ====================
class BookListTab extends StatelessWidget {
  final User user;
  final LibraryService service;
  const BookListTab({super.key, required this.user, required this.service});

  bool get _isLib => user.role == Role.librarian;

  Future<void> _openAdd(BuildContext context) async {
    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const AddBookDialog(),
    );
    if (data == null || !context.mounted) return;

    await runAction(context, () async {
      await service.addBook(
        user,
        data['type']!,
        data['id']!,
        data['title']!,
        data['author']!,
        stock: int.tryParse(data['stock'] ?? '') ?? 0,
        fileSizeMb: double.tryParse(data['size'] ?? '') ?? 0.0,
      );
      return 'Đã thêm sách "${data['title']}"';
    });
  }

  Future<void> _confirmDelete(BuildContext context, Book book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa sách?'),
        content: Text(
          'Bạn chắc chắn muốn xóa "${book.title}"?\n'
          'Các yêu cầu đang chờ của sách này sẽ bị từ chối.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runAction(context, () async {
      await service.deleteBook(user, book.id);
      return 'Đã xóa "${book.title}"';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final books = service.books;
        return Stack(
          children: [
            books.isEmpty
                ? const Center(
                    child: Text('Thư viện hiện chưa có đầu sách nào.'),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, _isLib ? 88 : 12),
                    itemCount: books.length,
                    itemBuilder: (_, i) {
                      final b = books[i];
                      return _BookCard(
                        book: b,
                        isLibrarian: _isLib,
                        borrowed: service.loanCount(user.username, b.id),
                        onRequestBorrow: () => runAction(
                          context,
                          () => service.requestBorrow(user, b.id),
                        ),
                        onRequestReturn: () => runAction(
                          context,
                          () => service.requestReturn(user, b.id),
                        ),
                        onDelete: () => _confirmDelete(context, b),
                      );
                    },
                  ),
            if (_isLib)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  onPressed: () => _openAdd(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm sách'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;
  final bool isLibrarian;
  final int borrowed;
  final VoidCallback onRequestBorrow, onRequestReturn, onDelete;

  const _BookCard({
    required this.book,
    required this.isLibrarian,
    required this.borrowed,
    required this.onRequestBorrow,
    required this.onRequestReturn,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final b = book;
    final isPrinted = b is PrintedBook;
    final lines = <String>[
      b.author,
      if (b is PrintedBook)
        '[${b.id}] • Còn ${b.stock}/${b.totalStock} cuốn trong kho'
      else if (b is EBook)
        '[${b.id}] • EBook ${b.fileSizeMb} MB',
      if (!isLibrarian && isPrinted && borrowed > 0)
        'Bạn đang mượn: $borrowed cuốn',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Icon(isPrinted ? Icons.menu_book : Icons.tablet_mac),
              ),
              title: Text(b.title),
              subtitle: Text(lines.join('\n')),
              isThreeLine: lines.length > 2,
              trailing: isLibrarian
                  ? IconButton(
                      tooltip: 'Xóa',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                    )
                  : null,
            ),
            if (!isLibrarian)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onRequestBorrow,
                    icon: const Icon(Icons.download),
                    label: const Text('Yêu cầu mượn'),
                  ),
                  if (isPrinted)
                    OutlinedButton.icon(
                      onPressed: onRequestReturn,
                      icon: const Icon(Icons.undo),
                      label: const Text('Yêu cầu trả'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class AddBookDialog extends StatefulWidget {
  const AddBookDialog({super.key});
  @override
  State<AddBookDialog> createState() => _AddBookDialogState();
}

class _AddBookDialogState extends State<AddBookDialog> {
  String _type = 'printed';
  final _id = TextEditingController();
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _stock = TextEditingController();
  final _size = TextEditingController();
  String? _error;

  @override
  void dispose() {
    for (final c in [_id, _title, _author, _stock, _size]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_id.text.trim().isEmpty || _title.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập Mã ID và Tên sách');
      return;
    }
    if (_type == 'printed' && (int.tryParse(_stock.text.trim()) ?? 0) <= 0) {
      setState(() => _error = 'Số lượng tồn kho phải là số nguyên > 0');
      return;
    }
    Navigator.pop(context, {
      'type': _type,
      'id': _id.text.trim(),
      'title': _title.text.trim(),
      'author': _author.text.trim(),
      'stock': _stock.text.trim(),
      'size': _size.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Thêm sách mới'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'printed', label: Text('Sách giấy')),
                ButtonSegment(value: 'ebook', label: Text('EBook')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _id,
              decoration: const InputDecoration(labelText: 'Mã ID'),
            ),
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Tên sách'),
            ),
            TextField(
              controller: _author,
              decoration: const InputDecoration(labelText: 'Tác giả'),
            ),
            if (_type == 'printed')
              TextField(
                controller: _stock,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số lượng nhập kho',
                ),
              )
            else
              TextField(
                controller: _size,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Dung lượng (MB)'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Thêm')),
      ],
    );
  }
}

// ==================== 11. TAB: YÊU CẦU ====================
class RequestsTab extends StatelessWidget {
  final User user;
  final LibraryService service;
  const RequestsTab({super.key, required this.user, required this.service});

  bool get _isLib => user.role == Role.librarian;

  Future<void> _reject(BuildContext context, BookRequest r) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Từ chối yêu cầu'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Lý do (không bắt buộc)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !context.mounted) return;
    await runAction(context, () => service.reject(user, r.id, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final list =
            service.requests
                .where((r) => _isLib || r.studentUsername == user.username)
                .toList()
              ..sort((a, b) {
                final pa = a.status == RequestStatus.pending ? 0 : 1;
                final pb = b.status == RequestStatus.pending ? 0 : 1;
                if (pa != pb) return pa - pb;
                return b.createdAt.compareTo(a.createdAt);
              });

        if (list.isEmpty) {
          return Center(
            child: Text(
              _isLib ? 'Chưa có yêu cầu nào.' : 'Bạn chưa gửi yêu cầu nào.',
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final r = list[i];
            return _RequestCard(
              request: r,
              showStudent: _isLib,
              onApprove: (_isLib && r.status == RequestStatus.pending)
                  ? () => runAction(context, () => service.approve(user, r.id))
                  : null,
              onReject: (_isLib && r.status == RequestStatus.pending)
                  ? () => _reject(context, r)
                  : null,
            );
          },
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final BookRequest request;
  final bool showStudent;
  final VoidCallback? onApprove, onReject;

  const _RequestCard({
    required this.request,
    required this.showStudent,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final r = request;
    final isBorrow = r.type == RequestType.borrow;

    final (label, color) = switch (r.status) {
      RequestStatus.pending => ('Chờ duyệt', Colors.orange.shade100),
      RequestStatus.approved => ('Đã duyệt', Colors.green.shade100),
      RequestStatus.rejected => ('Từ chối', Colors.red.shade100),
    };

    final lines = <String>[
      if (showStudent) 'Sinh viên: ${r.studentName} (${r.studentUsername})',
      'Gửi lúc: ${_fmt(r.createdAt)} • Mã ${r.id}',
      if (r.handledAt != null)
        'Xử lý: ${_fmt(r.handledAt!)} bởi ${r.handledBy}',
      if (r.reason != null) 'Lý do: ${r.reason}',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                child: Icon(isBorrow ? Icons.download : Icons.undo),
              ),
              title: Text('${isBorrow ? 'Mượn' : 'Trả'}: ${r.bookTitle}'),
              subtitle: Text(lines.join('\n')),
              isThreeLine: lines.length > 2,
              trailing: Chip(
                label: Text(label),
                backgroundColor: color,
                visualDensity: VisualDensity.compact,
              ),
            ),
            if (onApprove != null || onReject != null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check),
                    label: const Text('Duyệt'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Từ chối'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
