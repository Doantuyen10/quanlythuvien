# Quản lý thư viện (Flutter)

Ứng dụng demo quản lý thư viện viết bằng Dart/Flutter, dùng để minh họa **OOP nâng cao**, **Design Patterns** (Repository, Factory) và **xử lý ngoại lệ** trong một module nghiệp vụ có phân quyền.

## Tính năng

Ứng dụng có hai vai trò, đăng nhập bằng tài khoản demo.

**Thủ kho (librarian)**
- Thêm sách in (có số lượng tồn kho) hoặc sách điện tử (có dung lượng file).
- Xóa sách; các yêu cầu đang chờ của sách đó tự động bị từ chối.
- Duyệt hoặc từ chối yêu cầu mượn/trả của sinh viên (có thể ghi lý do khi từ chối).

**Sinh viên (student)**
- Xem danh sách sách.
- Gửi yêu cầu mượn và yêu cầu trả. Mọi yêu cầu phải chờ thủ kho duyệt.
- Sách điện tử không cần trả.

### Tài khoản demo

| Vai trò | Tên đăng nhập | Mật khẩu |
|---|---|---|
| Thủ kho | `admin` | `admin` |
| Sinh viên | `sv01` | `123` |
| Sinh viên | `sv02` | `123` |

Dữ liệu mẫu được nạp khi khởi động: sách in `SK01` (2 cuốn) và sách điện tử `EB01`. Dữ liệu lưu trong bộ nhớ nên sẽ mất khi tắt ứng dụng.

## Quy tắc nghiệp vụ

1. Mã sách (ID) là duy nhất.
2. Sách in chỉ được mượn khi còn tồn kho; số lượng nhập phải lớn hơn 0.
3. Chỉ được trả sách đã mượn, và số sách trong kho không vượt quá số lượng đã nhập.
4. Mỗi sinh viên chỉ có một yêu cầu chờ duyệt cho cùng một sách và cùng loại thao tác.
5. Yêu cầu đã xử lý không được xử lý lại.
6. Mỗi thao tác được kiểm tra vai trò trước khi thực hiện.

## Cấu trúc dự án

```text
lib/
├── Library.dart   # Exception, mixin, Domain, Repository, Service
└── main.dart      # Giao diện + hàm bắt lỗi runAction
```

`Library.dart` được chia thành các phần:

| Phần | Nội dung |
|---|---|
| 1. Custom exceptions | `LibraryException` và các lớp con |
| 2. Mixins | `Loggable` ghi log qua `debugPrint` |
| 3. Domain Layer | `User`, `Role`, `Book`, `EBook`, `PrintedBook`, `BookRequest` và các enum |
| 4. Repository Pattern | `Repository<T>`, `BookRepository`, `RequestRepository` |
| 5. Services | `AuthService`, `LibraryService` (kế thừa `ChangeNotifier`) |

`main.dart` gồm: hàm tiện ích (`showToast`, `runAction`), `LibraryApp`, `LoginPage`, `HomePage`, `BookListTab`, `AddBookDialog`, `RequestsTab`.

## Kỹ thuật OOP và Design Patterns

| Kỹ thuật | Vị trí |
|---|---|
| Factory constructor / Factory Pattern | `Book.create` tạo `EBook` hoặc `PrintedBook` theo tham số `type` |
| Repository Pattern | `Repository<T>` và hai lớp cài đặt lưu trong bộ nhớ |
| Generics | `Repository<Book>`, `Repository<BookRequest>` |
| Mixin | `Loggable` được dùng bởi hai repository (`with Loggable`) |
| Kế thừa và đa hình | `EBook`, `PrintedBook` kế thừa `Book`; các exception kế thừa `LibraryException` |
| Enum | `Role`, `RequestType`, `RequestStatus` |
| Super parameter, initializer list | Constructor của `EBook`, `PrintedBook` |
| Const constructor | `User` |
| Observer | `LibraryService extends ChangeNotifier`, UI lắng nghe bằng `ListenableBuilder` |
| Dependency Injection | `LibraryService(BookRepository(), RequestRepository())` |
| Đóng gói | Thành viên riêng tư (`_books`, `_loans`, `_requireRole`), `List.unmodifiable` |

## Xử lý ngoại lệ

Mọi lỗi nghiệp vụ kế thừa từ `LibraryException` và mang thông điệp tiếng Việt để hiển thị trực tiếp.

| Exception | Khi nào được ném |
|---|---|
| `BookNotFoundException` | Không tìm thấy sách theo ID |
| `DuplicateBookException` | Thêm sách trùng ID |
| `OutOfStockException` | Mượn khi kho hết sách |
| `ReturnLimitException` | Trả vượt quá số lượng đã nhập |
| `NotBorrowedException` | Trả sách chưa mượn |
| `DuplicateRequestException` | Gửi trùng yêu cầu đang chờ |
| `RequestNotFoundException` | Không tìm thấy yêu cầu |
| `RequestAlreadyHandledException` | Xử lý lại yêu cầu đã xử lý |
| `PermissionDeniedException` | Sai vai trò khi thao tác |
| `AuthException` | Đăng nhập sai tài khoản, mật khẩu hoặc vai trò |

Cách xử lý:

- Giao diện gọi mọi thao tác qua `runAction`, hàm này bắt `LibraryException`, `ArgumentError` và lỗi không lường trước rồi hiển thị bằng `SnackBar`.
- Ở tầng service, các thao tác dùng `try ... finally` để luôn làm mới dữ liệu và thông báo cho giao diện, kể cả khi có lỗi.

## Chạy ứng dụng

Yêu cầu: Flutter SDK (Dart 3.x).

```bash
flutter create library_app
cd library_app
# chép Library.dart và main.dart vào thư mục lib/ (ghi đè main.dart)
flutter run
```

Ứng dụng không cần thêm package ngoài `flutter`.

## Hạn chế hiện tại và hướng phát triển

- Lỗi chỉ hiển thị trên giao diện, **chưa được ghi log**; `Loggable` hiện chỉ ghi các thao tác thành công.
- `main()` chưa có error boundary (`runZonedGuarded`, `FlutterError.onError`, `PlatformDispatcher.instance.onError`).
- Màn hình đăng nhập tự bắt lỗi riêng, chưa đi qua `runAction`.
- `Library.dart` import `flutter/foundation` và `LibraryService` kế thừa `ChangeNotifier`, nên Domain Layer chưa hoàn toàn độc lập với Flutter. Nên tách thành các file `domain/`, `data/`, `core/`.
- `LibraryService` phụ thuộc vào lớp repository cụ thể thay vì `Repository<T>`; nên khai báo theo abstraction để dễ thay bằng bản giả khi kiểm thử.
- `Book.create` nhận `type` dạng chuỗi; nên đổi sang enum.
- Mật khẩu lưu dạng văn bản thường và dữ liệu chỉ nằm trong bộ nhớ, chỉ phù hợp mục đích demo.
- Hướng mở rộng: lưu trữ bền vững (SQLite/REST), thêm `ErrorHandler` tập trung kèm ghi log ra file hoặc dịch vụ giám sát, viết unit test cho `LibraryService`.