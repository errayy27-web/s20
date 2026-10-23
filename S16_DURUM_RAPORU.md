# S16 Kontrol Raporu

Bu paket S15 modal sürümünden üretilmiştir.

## Kaynakta uygulanan
- Kasa fonksiyonu byte-for-byte korunmuştur; PC sunucusu bu ZIP içinde değiştirilmemiştir.
- Barkod bulunamadığında yerel hata kaydı, listeleme, durum düzenleme, silme ve XLSX dışa aktarma. Mevcut PC sunucusu barkodErrors bölümünü kabul etmediği için merkezi gönderim YOK.
- Sipariş KOM/PAK seçimi telefonda tutulur; mevcut PC sunucusu orderUnits bölümünü kabul etmediğinden merkezi eşitleme YOK.
- Özel etiket genişlik/yükseklik ve iç boşluk ayarları eklenmiştir.
- Temizle sonrası PC eşitlemesi bekleniyorsa kullanıcıya açık uyarı verilir.
- Diğer önceki S15 özellikleri korunmuştur.

## Eksik / doğrulanmadı
- Gerçek Supabase köprüsü ve üç telefon arasında uçtan uca eşitleme. Supabase anahtarları ve köprü kurulumu gerekir.
- PC'den silme onayı, yarış durumları ve aynı anda iki telefonun değişikliklerini çakışmasız birleştirme. /shared son yazan kazanır mantığı kullanır.
- Stok farkının tüm cihazlarda aynı merkez stok referansından hesaplanması.
- KOM ve PAK için ayrı miktar satırları ve aynı anda artırmada atomik toplama.
- Barkod hatası dışında yerel fotoğrafların bulut aktarımı.
- Etiket kağıdı kenar/ara boşluk ayarı ve gerçek yazıcı testi.
- Flutter SDK yok: derleme, analiz ve cihaz testi yapılmadı.

Mevcut çalışan APK üzerine doğrudan kurmayın.
