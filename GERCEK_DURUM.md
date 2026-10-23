# SS OIL — Kaynak güncelleme, test edilmemiş

Bu paket derlenmiş APK değildir. Flutter SDK bu ortamda bulunmadığı için derleme, bağımlılık çözümleme ve cihaz testleri yapılmamıştır. Çalışan uygulamanın yerine doğrudan kurmayın.

## Kaynak kodda düzenlenenler
- Kasa hesaplama ve veri çekme fonksiyonları değiştirilmedi.
- Stokta tedarikçiye göre filtreleme.
- Ürün detayının ortada, kaydırılabilir Dialog içinde açılması.
- Tedarikçiye dokununca ayrı açılır sipariş penceresi, KOM/PAK ve -/+ /sil.
- Stok sayımında sayılan toplam miktar ile mevcut tahmini stokun farkı; pozitif/negatif sayı; sayım barkodundan giriş.
- Excel çıktılarında CSV yerine XLSX ve Kaydet / Paylaş menüsü; tedarikçi başına sayfa; toplu rapor.
- Etiket barkodunun küçültülmesi ve barkod numarasının ayrı okunur yazılması; 9 etiketlik sayfa seçeneği.
- Ayarlarda etiket, sipariş, eksik/fazla için onaylı toplu temizleme.
- Mevcut /shared merkez senkronizasyonunun kontrol aralığı 3 saniyeye indirildi; PC sunucusuna dokunulmadı.

## Tamamlanmamış ve doğrulanmamış olanlar
- Flutter derleme ve telefon testi yapılmadı. Bu nedenle kaynak kodun hatasız derlendiği söylenemez.
- Supabase telefon kimlik doğrulaması ve üç telefonlu canlı senkronizasyon entegrasyonu tamamlanmadı. Bulut köprüsü ayrıca kurulmalıdır.
- Mevcut PC /shared sunucusu orderUnits ve barkod hataları bölümlerini kabul etmiyor; bunların merkezi aktarımı tamamlanmadı.
- PC merkezinde olayların kalıcı tabloya (orders, labels, stock_adjustments) işlenmesi ayrı olarak doğrulanmadı. /shared olay tablosu ve işlevsel tablolar farklıdır.
- Stok farkı telefonun mevcut `remaining()` hesabına dayanır; farklı cihazlarda stok başlangıcı değişirse sayım referansı farklı olabilir.
- 38x25 mm etiket sayfasının fiziksel kağıt kenar boşlukları ve 9'lu dizilimi yazıcıda ölçülüp test edilmedi.
- Barkod hataları yönetimi ve tüm bölümler için merkezi temizleme tamamlanmadı.
- KOM/PAK birimi telefonda kaydedilir, PC sunucusuna ayrı alan olarak aktarılmaz.

## Güvenlik
- Gerçek API tokeni ve Supabase service_role anahtarı APK içine gömülmemelidir.
- PC sunucusu dosyaları pakete dahil edilmedi, değiştirilmedi.
