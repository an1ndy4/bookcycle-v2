# BookCycle Chat Realtime patch

Patch ini ditujukan untuk source utama Flutter pada folder `lib/` (bukan salinan lama di `ios/lib/`).

## File yang diperbarui

- `lib/services/chat_service.dart`
  - Menggunakan `auth_id` untuk memetakan UUID Supabase Auth ke `public.users.user_id`.
  - Mengambil seluruh riwayat antara dua pengguna tanpa memfilter `buku_id`.
  - Menyimpan `buku_id` pada pesan baru sebagai konteks, bukan sebagai pemisah thread.
  - Menghapus pengiriman kolom `sudah_dibaca` saat INSERT karena database menyediakan default `false` dan hak INSERT aplikasi sengaja dibatasi.
  - Menandai seluruh pesan masuk dari lawan bicara sebagai terbaca.

- `lib/controllers/chat_controller.dart`
  - Menangani INSERT dan UPDATE dari Realtime.
  - Mencegah pesan ganda berdasarkan `chat_id`.
  - Menggabungkan hasil query dengan event yang tiba saat query berlangsung.
  - Menjaga status baca yang lebih baru ketika sinkronisasi berlangsung.

- `lib/views/widgets/chat_screen.dart`
  - Berlangganan event INSERT untuk pesan masuk dan UPDATE untuk status baca pesan keluar, dengan filter per pasangan pengguna.
  - Membuat satu channel per pasangan pengguna, bukan per buku.
  - Memasang listener sebelum pemuatan awal untuk mengurangi risiko event terlewat.
  - Sinkronisasi ulang setelah koneksi Realtime tersambung kembali.
  - Menampilkan centang satu dan dua pada pesan keluar serta status koneksi Realtime di header.

## Konfigurasi package

Tidak ada package tambahan. `pubspec.yaml` tetap memakai `supabase_flutter: ^2.5.0` dan `provider: ^6.1.1`. Arsip project yang diaudit memiliki `pubspec.lock` dengan `supabase_flutter 2.18.3` dan `realtime_client 2.13.2`.

## Database

File `supabase/migrations/20261112000100_bookcycle_chat_realtime.sql` mendokumentasikan konfigurasi RLS, grants, dan publication `supabase_realtime` yang telah diterapkan pada project Supabase BookCycle.

## Pengujian setelah patch diterapkan

1. Jalankan `flutter pub get`.
2. Jalankan `flutter analyze`.
3. Login dengan dua akun berbeda pada dua perangkat/browser.
4. Buka chat dari akun A ke akun B dan kirim pesan dari A.
5. Pastikan pesan muncul di B tanpa refresh.
6. Buka chat di B dan pastikan centang pesan pada A berubah menjadi dua setelah dibaca.
7. Kirim pesan terkait buku lain kepada penjual yang sama dan pastikan pesan tetap berada pada thread yang sama.
8. Putuskan dan pulihkan koneksi internet; pastikan riwayat tersinkron kembali.

Catatan: Flutter SDK tidak tersedia pada lingkungan audit ini, sehingga `flutter analyze` dan uji dua akun belum dapat dijalankan di sini. Konfigurasi database telah diverifikasi secara langsung, termasuk uji INSERT dan update status baca dalam transaksi yang di-rollback. Push notification belum termasuk patch ini; patch menangani pesan langsung di aplikasi saat chat terbuka.
