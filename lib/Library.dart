import 'package:flutter/foundation.dart';

// ==================== 1. CUSTOM EXCEPTIONS ====================
class LibraryException implements Exception {
  final String message;
  LibraryException(this.message);
  @override
  String toString() => message;
}

class BookNotFoundException extends LibraryException {
  BookNotFoundException(String id)
    : super("Không tìm thấy sách với mã ID: '$id'");
}

class OutOfStockException extends LibraryException {
  OutOfStockException(String title)
    : super("Sách '$title' đã hết bản trong kho để cho mượn!");
}

class DuplicateBookException extends LibraryException {
  DuplicateBookException(String id) : super("Mã ID '$id' đã tồn tại!");
}

/// Trả vượt quá số lượng đã nhập kho
class ReturnLimitException extends LibraryException {
  ReturnLimitException(String title, int total)
    : super(
        "Không thể trả '$title': kho đã đủ $total/$total cuốn, "
        "không thể nhận thêm vượt quá số lượng đã nhập!",
      );
}

class NotBorrowedException extends LibraryException {
  NotBorrowedException(String title)
    : super("Bạn chưa mượn sách '$title' nên không thể trả!");
}

class DuplicateRequestException extends LibraryException {
  DuplicateRequestException()
    : super("Bạn đã có yêu cầu đang chờ duyệt cho sách này!");
}

class RequestNotFoundException extends LibraryException {
  RequestNotFoundException(String id)
    : super("Không tìm thấy yêu cầu mã '$id'");
}

class RequestAlreadyHandledException extends LibraryException {
  RequestAlreadyHandledException()
    : super("Yêu cầu này đã được xử lý trước đó!");
}

class PermissionDeniedException extends LibraryException {
  PermissionDeniedException()
    : super("Bạn không có quyền thực hiện thao tác này!");
}

class AuthException extends LibraryException {
  AuthException() : super("Sai tài khoản, mật khẩu hoặc vai trò!");
}

// ==================== 2. MIXINS ====================
mixin Loggable {
  void log(String message) {
    final timestamp = DateTime.now().toIso8601String().split('T').last;
    debugPrint("[$timestamp] [SYSTEM LOG]: $message");
  }
}

// ==================== 3. DOMAIN LAYER ====================
enum Role { student, librarian }

class User {
  final String username;
  final String password;
  final String name;
  final Role role;
  const User({
    required this.username,
    required this.password,
    required this.name,
    required this.role,
  });
}

abstract class Book {
  final String id;
  final String title;
  final String author;

  Book({required this.id, required this.title, required this.author});

  factory Book.create({
    required String type,
    required String id,
    required String title,
    required String author,
    int stock = 0,
    double fileSizeMb = 0.0,
  }) {
    if (type.toLowerCase() == 'ebook') {
      return EBook(
        id: id,
        title: title,
        author: author,
        fileSizeMb: fileSizeMb,
      );
    } else if (type.toLowerCase() == 'printed') {
      if (stock <= 0) {
        throw ArgumentError("Số lượng tồn kho phải lớn hơn 0");
      }
      return PrintedBook(id: id, title: title, author: author, stock: stock);
    } else {
      throw ArgumentError("Loại sách không hợp lệ: $type");
    }
  }
}

class EBook extends Book {
  final double fileSizeMb;
  EBook({
    required super.id,
    required super.title,
    required super.author,
    required this.fileSizeMb,
  });
}

class PrintedBook extends Book {
  /// Số cuốn hiện có trong kho
  int stock;

  /// Tổng số cuốn đã nhập vào kho (giới hạn tối đa khi nhận trả)
  final int totalStock;

  PrintedBook({
    required super.id,
    required super.title,
    required super.author,
    required int stock,
  }) : stock = stock,
       totalStock = stock;
}

enum RequestType { borrow, ret }

enum RequestStatus { pending, approved, rejected }

class BookRequest {
  final String id;
  final String bookId;
  final String bookTitle;
  final String studentUsername;
  final String studentName;
  final RequestType type;
  final DateTime createdAt;
  RequestStatus status = RequestStatus.pending;
  DateTime? handledAt;
  String? handledBy;
  String? reason;

  BookRequest({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.studentUsername,
    required this.studentName,
    required this.type,
    required this.createdAt,
  });
}

// ==================== 4. REPOSITORY PATTERN ====================
abstract class Repository<T> {
  Future<List<T>> getAll();
  Future<T?> getById(String id);
  Future<void> add(T item);
  Future<void> delete(String id);
}

class BookRepository with Loggable implements Repository<Book> {
  final List<Book> _books = [];

  @override
  Future<List<Book>> getAll() async => List.unmodifiable(_books);

  @override
  Future<Book?> getById(String id) async {
    for (final b in _books) {
      if (b.id == id) return b;
    }
    return null;
  }

  @override
  Future<void> add(Book item) async {
    if (await getById(item.id) != null) throw DuplicateBookException(item.id);
    _books.add(item);
    log("Đã thêm thành công sách: ${item.title}");
  }

  @override
  Future<void> delete(String id) async {
    final book = await getById(id);
    if (book == null) throw BookNotFoundException(id);
    _books.removeWhere((b) => b.id == id);
    log("Đã xóa sách có ID: $id");
  }
}

class RequestRepository with Loggable implements Repository<BookRequest> {
  final List<BookRequest> _items = [];

  @override
  Future<List<BookRequest>> getAll() async => List.unmodifiable(_items);

  @override
  Future<BookRequest?> getById(String id) async {
    for (final r in _items) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<void> add(BookRequest item) async {
    _items.add(item);
    log("Yêu cầu mới ${item.id}: ${item.type.name} '${item.bookTitle}'");
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((r) => r.id == id);
  }
}

// ==================== 5. SERVICES ====================
class AuthService {
  // Tài khoản demo
  final List<User> _users = const [
    User(
      username: 'admin',
      password: 'admin',
      name: 'Thủ kho Minh',
      role: Role.librarian,
    ),
    User(
      username: 'sv01',
      password: '123',
      name: 'Nguyễn Văn An',
      role: Role.student,
    ),
    User(
      username: 'sv02',
      password: '123',
      name: 'Trần Thị Bình',
      role: Role.student,
    ),
  ];

  User login(String username, String password, Role role) {
    for (final u in _users) {
      if (u.username == username && u.password == password && u.role == role) {
        return u;
      }
    }
    throw AuthException();
  }
}

class LibraryService extends ChangeNotifier {
  final BookRepository _bookRepo;
  final RequestRepository _requestRepo;

  /// username -> (bookId -> số cuốn đang mượn)
  final Map<String, Map<String, int>> _loans = {};

  List<Book> _books = [];
  List<BookRequest> _requests = [];
  int _seq = 0;

  LibraryService(this._bookRepo, this._requestRepo);

  List<Book> get books => _books;
  List<BookRequest> get requests => _requests;
  int get pendingCount =>
      _requests.where((r) => r.status == RequestStatus.pending).length;

  int loanCount(String username, String bookId) =>
      _loans[username]?[bookId] ?? 0;

  void _addLoan(String username, String bookId, int delta) {
    final m = _loans.putIfAbsent(username, () => {});
    final n = (m[bookId] ?? 0) + delta;
    if (n <= 0) {
      m.remove(bookId);
    } else {
      m[bookId] = n;
    }
  }

  void _requireRole(User user, Role role) {
    if (user.role != role) throw PermissionDeniedException();
  }

  Future<void> _refresh() async {
    _books = await _bookRepo.getAll();
    _requests = await _requestRepo.getAll();
    notifyListeners();
  }

  /// Dữ liệu mẫu
  Future<void> seed() async {
    await _bookRepo.add(
      Book.create(
        type: 'printed',
        id: 'SK01',
        title: 'Lập trình Dart căn bản',
        author: 'Nguyễn Văn A',
        stock: 2,
      ),
    );
    await _bookRepo.add(
      Book.create(
        type: 'ebook',
        id: 'EB01',
        title: 'Clean Code Architecture',
        author: 'Robert C. Martin',
        fileSizeMb: 12.5,
      ),
    );
    await _refresh();
  }

  // ---------- Quản kho: thêm / xóa sách ----------
  Future<void> addBook(
    User actor,
    String type,
    String id,
    String title,
    String author, {
    int stock = 0,
    double fileSizeMb = 0.0,
  }) async {
    _requireRole(actor, Role.librarian);
    try {
      final newBook = Book.create(
        type: type,
        id: id,
        title: title,
        author: author,
        stock: stock,
        fileSizeMb: fileSizeMb,
      );
      await _bookRepo.add(newBook);
    } finally {
      await _refresh();
    }
  }

  Future<void> deleteBook(User actor, String id) async {
    _requireRole(actor, Role.librarian);
    try {
      await _bookRepo.delete(id);
      // Từ chối các yêu cầu đang chờ của sách đã xóa
      for (final r in await _requestRepo.getAll()) {
        if (r.bookId == id && r.status == RequestStatus.pending) {
          r.status = RequestStatus.rejected;
          r.handledAt = DateTime.now();
          r.handledBy = actor.name;
          r.reason = "Sách đã bị xóa khỏi kho";
        }
      }
      for (final m in _loans.values) {
        m.remove(id);
      }
    } finally {
      await _refresh();
    }
  }

  // ---------- Sinh viên: gửi yêu cầu ----------
  void _ensureNoPending(User user, String bookId, RequestType type) {
    final exists = _requests.any(
      (r) =>
          r.studentUsername == user.username &&
          r.bookId == bookId &&
          r.type == type &&
          r.status == RequestStatus.pending,
    );
    if (exists) throw DuplicateRequestException();
  }

  Future<void> _createRequest(User user, Book book, RequestType type) async {
    _seq++;
    await _requestRepo.add(
      BookRequest(
        id: 'RQ${_seq.toString().padLeft(3, '0')}',
        bookId: book.id,
        bookTitle: book.title,
        studentUsername: user.username,
        studentName: user.name,
        type: type,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<String> requestBorrow(User user, String bookId) async {
    _requireRole(user, Role.student);
    try {
      final book = await _bookRepo.getById(bookId);
      if (book == null) throw BookNotFoundException(bookId);
      if (book is PrintedBook && book.stock <= 0) {
        throw OutOfStockException(book.title);
      }
      _ensureNoPending(user, bookId, RequestType.borrow);
      await _createRequest(user, book, RequestType.borrow);
      return "Đã gửi yêu cầu mượn '${book.title}'. Vui lòng chờ quản kho duyệt.";
    } finally {
      await _refresh();
    }
  }

  Future<String> requestReturn(User user, String bookId) async {
    _requireRole(user, Role.student);
    try {
      final book = await _bookRepo.getById(bookId);
      if (book == null) throw BookNotFoundException(bookId);
      if (book is! PrintedBook) {
        throw LibraryException("EBook không cần trả.");
      }
      if (loanCount(user.username, bookId) <= 0) {
        throw NotBorrowedException(book.title);
      }
      if (book.stock >= book.totalStock) {
        throw ReturnLimitException(book.title, book.totalStock);
      }
      _ensureNoPending(user, bookId, RequestType.ret);
      await _createRequest(user, book, RequestType.ret);
      return "Đã gửi yêu cầu trả '${book.title}'. Vui lòng chờ quản kho duyệt.";
    } finally {
      await _refresh();
    }
  }

  // ---------- Quản kho: duyệt / từ chối ----------
  Future<String> approve(User actor, String requestId) async {
    _requireRole(actor, Role.librarian);
    try {
      final req = await _requestRepo.getById(requestId);
      if (req == null) throw RequestNotFoundException(requestId);
      if (req.status != RequestStatus.pending) {
        throw RequestAlreadyHandledException();
      }
      final book = await _bookRepo.getById(req.bookId);
      if (book == null) throw BookNotFoundException(req.bookId);

      if (req.type == RequestType.borrow) {
        if (book is PrintedBook) {
          if (book.stock <= 0) throw OutOfStockException(book.title);
          book.stock--;
          _addLoan(req.studentUsername, book.id, 1);
        }
      } else {
        if (book is! PrintedBook) {
          throw LibraryException("EBook không cần trả.");
        }
        if (loanCount(req.studentUsername, book.id) <= 0) {
          throw NotBorrowedException(book.title);
        }
        if (book.stock >= book.totalStock) {
          throw ReturnLimitException(book.title, book.totalStock);
        }
        book.stock++;
        _addLoan(req.studentUsername, book.id, -1);
      }

      req.status = RequestStatus.approved;
      req.handledAt = DateTime.now();
      req.handledBy = actor.name;
      return "Đã duyệt yêu cầu ${req.id} của ${req.studentName}";
    } finally {
      await _refresh();
    }
  }

  Future<String> reject(User actor, String requestId, {String? reason}) async {
    _requireRole(actor, Role.librarian);
    try {
      final req = await _requestRepo.getById(requestId);
      if (req == null) throw RequestNotFoundException(requestId);
      if (req.status != RequestStatus.pending) {
        throw RequestAlreadyHandledException();
      }
      req.status = RequestStatus.rejected;
      req.handledAt = DateTime.now();
      req.handledBy = actor.name;
      req.reason = (reason == null || reason.trim().isEmpty)
          ? null
          : reason.trim();
      return "Đã từ chối yêu cầu ${req.id} của ${req.studentName}";
    } finally {
      await _refresh();
    }
  }
}
