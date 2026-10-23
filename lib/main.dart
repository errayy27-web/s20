import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';

const gold=Color(0xffffc83d), bg=Color(0xff0b1019), panel=Color(0xff172130);
void main()=>runApp(const OilApp());
num number(dynamic v)=>num.tryParse('$v')??0;
String money(dynamic n)=>number(n).toStringAsFixed(2).replaceAll('.',',');
String day(DateTime d)=>'${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
Map<String,dynamic> map(dynamic x)=>x is Map?Map<String,dynamic>.from(x):{};
List<dynamic> list(dynamic x)=>x is List?x:[];
class OilApp extends StatelessWidget {const OilApp({super.key}); @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,title:'SS OIL',theme:ThemeData(useMaterial3:true,brightness:Brightness.dark,scaffoldBackgroundColor:bg,colorScheme:ColorScheme.fromSeed(seedColor:gold,brightness:Brightness.dark),cardColor:panel,inputDecorationTheme:InputDecorationTheme(border:OutlineInputBorder(borderRadius:BorderRadius.circular(14))),appBarTheme:const AppBarTheme(backgroundColor:bg)),home:const OilHome());}
class OilHome extends StatefulWidget {const OilHome({super.key}); @override State<OilHome> createState()=>_OilHomeState();}
class _OilHomeState extends State<OilHome> {
 SharedPreferences? prefs; int page=0; bool busy=false; String message='', source='Çevrimdışı';
 String local='http://192.168.100.13:8767',cloud='',token='',coffeeUrl='',fuelIds='',supabaseUrl='',supabaseKey='',cloudStatus='Test edilmedi';
 List<Map<String,dynamic>> products=[]; Map<String,dynamic> kasa={};
 Map<String,dynamic> base={},previousSales={},daily={},photos={},suppliers={},supplierOf={},minimum={},orders={},labels={},orderUnits={},discrepancies={},barcodeErrors={};
 DateTime selected=DateTime.now();
 Timer? syncTimer; bool syncing=false; int syncRevision=0; List<dynamic> pending=[]; Map<String,dynamic> tracked={};
 Map<String,dynamic> get sharedData=>{'labels':labels,'orders':orders,'suppliers':suppliers,'supplierOf':supplierOf,'minimum':minimum,'discrepancies':discrepancies};
 @override void initState(){super.initState();load();}
 @override void dispose(){syncTimer?.cancel();super.dispose();}
 Future<void> load()async{prefs=await SharedPreferences.getInstance(); if(!mounted)return;setState((){local=prefs!.getString('local')??local;cloud=prefs!.getString('cloud')??'';supabaseUrl=prefs!.getString('supabaseUrl')??'';supabaseKey=prefs!.getString('supabaseKey')??'';token=prefs!.getString('token')??'';coffeeUrl=prefs!.getString('coffee')??'';fuelIds=prefs!.getString('fuelIds')??'';products=list(jsonDecode(prefs!.getString('products')??'[]')).map((e)=>map(e)).toList();base=map(jsonDecode(prefs!.getString('base')??'{}'));previousSales=map(jsonDecode(prefs!.getString('previousSales')??'{}'));daily=map(jsonDecode(prefs!.getString('daily')??'{}'));photos=map(jsonDecode(prefs!.getString('photos')??'{}'));suppliers=map(jsonDecode(prefs!.getString('suppliers')??'{}'));supplierOf=map(jsonDecode(prefs!.getString('supplierOf')??'{}'));minimum=map(jsonDecode(prefs!.getString('minimum')??'{}'));orders=map(jsonDecode(prefs!.getString('orders')??'{}'));labels=map(jsonDecode(prefs!.getString('labels')??'{}'));orderUnits=map(jsonDecode(prefs!.getString('orderUnits')??'{}'));discrepancies=map(jsonDecode(prefs!.getString('discrepancies')??'{}'));barcodeErrors=map(jsonDecode(prefs!.getString('barcodeErrors')??'{}'));});syncRevision=prefs!.getInt('syncRevision')??0;pending=list(jsonDecode(prefs!.getString('syncPending')??'[]'));tracked=map(jsonDecode(prefs!.getString('syncTracked')??'{}'));syncTimer=Timer.periodic(const Duration(seconds:3),(_)=>syncShared());syncShared();}
 Future<void> save()async{final p=prefs;if(p==null)return;for(final e in <String,dynamic>{'local':local,'cloud':cloud,'supabaseUrl':supabaseUrl,'supabaseKey':supabaseKey,'token':token,'coffee':coffeeUrl,'fuelIds':fuelIds,'products':products,'base':base,'previousSales':previousSales,'daily':daily,'photos':photos,'suppliers':suppliers,'supplierOf':supplierOf,'minimum':minimum,'orders':orders,'labels':labels,'orderUnits':orderUnits,'discrepancies':discrepancies,'barcodeErrors':barcodeErrors}.entries){await p.setString(e.key,e.value is String?e.value:jsonEncode(e.value));}await queueSharedChanges();syncShared();}
 Future<void> queueSharedChanges()async{
  for(final entry in sharedData.entries){
   final old=map(tracked[entry.key]); final current=map(entry.value);
   for(final key in {...old.keys,...current.keys}){
    if(jsonEncode(old[key])==jsonEncode(current[key]))continue;
    pending.add({'section':entry.key,'key':key,'value':current[key],'event_id':'${DateTime.now().microsecondsSinceEpoch}_${pending.length}_${entry.key}_$key'});
   }
  }
  tracked={for(final e in sharedData.entries)e.key:Map<String,dynamic>.from(e.value)};
  await prefs?.setString('syncTracked',jsonEncode(tracked));
  await prefs?.setString('syncPending',jsonEncode(pending));
 }
 Future<void> syncShared()async{
  if(syncing||prefs==null)return;syncing=true;
  try{
   for(final event in List<dynamic>.from(pending)){
    final result=await apiPost('/shared',map(event));
    if(result==null)break;
    pending.removeAt(0);
    await prefs!.setString('syncPending',jsonEncode(pending));
   }
   if(pending.isNotEmpty)return;
   final result=await api('/shared?since=$syncRevision');
   for(final event in list(result['changes'])){
    final e=map(event);final section='${e['section']}',key='${e['key']}';
    final target=sharedData[section];if(target==null)continue;
    if(e['value']==null){target.remove(key);}else{target[key]=e['value'];}
    syncRevision=number(e['revision']).toInt();
   }
   // The server returns at most 2000 events. Fetch remaining pages on the next tick.
   await prefs!.setInt('syncRevision',syncRevision);
   tracked={for(final e in sharedData.entries)e.key:Map<String,dynamic>.from(e.value)};
   await prefs!.setString('syncTracked',jsonEncode(tracked));
   for(final e in sharedData.entries){await prefs!.setString(e.key,jsonEncode(e.value));}
   if(mounted)setState((){});
  }catch(_){/* Offline edits remain queued locally. */}finally{syncing=false;}
 }
 Future<Map<String,dynamic>?> apiPost(String route,Map<String,dynamic> payload)async{
  for(final address in [local,cloud]){
   if(address.trim().isEmpty)continue;
   try{
    final r=await http.post(Uri.parse('${address.replaceAll(RegExp(r"/$"),'')}$route'),headers:{'X-SSOIL-Token':token,'Content-Type':'application/json'},body:jsonEncode(payload)).timeout(const Duration(seconds:5));
    if(r.statusCode==200)return map(jsonDecode(utf8.decode(r.bodyBytes)));
   }catch(_){ }
  }
  return null;
 }
 Future<Map<String,dynamic>> api(String route)async{for(final entry in [('Yerel ağ',local),('Bulut',cloud)]){if(entry.$2.trim().isEmpty)continue;try{final r=await http.get(Uri.parse('${entry.$2.replaceAll(RegExp(r"/$"),'')}$route'),headers:{'X-SSOIL-Token':token}).timeout(const Duration(seconds:5));if(r.statusCode==200){if(mounted)setState(()=>source=entry.$1);return map(jsonDecode(utf8.decode(r.bodyBytes)));}if(r.statusCode==401)throw Exception('Yetkilendirme hatası'); if(r.statusCode>=400)throw Exception('HTTP ${r.statusCode}: ${r.body}');}catch(_){}}throw Exception('Yerel sunucu ve yapılandırılmış bulut erişilemiyor');}
 void notice(String s){if(!mounted)return;setState(()=>message=s);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));}
 Future<void> refreshStock()async{setState(()=>busy=true);try{final s=await api('/snapshot');final sl=await api('/sales');final incoming=list(s['products']).map((e)=>map(e)).toList();final sold=map(sl['sales']);setState((){products=incoming;base={for(final p in incoming)'${p['id']}':number(p['stock'])};previousSales=sold;});await prefs!.setString('stockBaselineSales',jsonEncode(sold));await save();notice('${products.length} ürün ve başlangıç stokları güncellendi');}catch(e){notice('Stok alınamadı: $e');}finally{if(mounted)setState(()=>busy=false);}}
 Future<void> refreshSales()async{setState(()=>busy=true);try{try{final central=await api('/daily-sales');setState(()=>daily=map(central['daily']));await prefs?.setString('daily',jsonEncode(daily));notice('PC günlük satış kayıtları güncellendi');return;}catch(_){ }final result=await api('/sales');final now=map(result['sales']);final today=day(DateTime.now());final bucket=map(daily[today]);for(final p in products){final id='${p['id']}';final current=number(now[id]);final old=number(previousSales[id]);final delta=max(0,current-old);if(delta>0)bucket[id]=number(bucket[id])+delta;previousSales[id]=current;}daily[today]=bucket;final oldest=day(DateTime.now().subtract(const Duration(days:6)));daily.removeWhere((date,_)=>date.compareTo(oldest)<0);await save();notice('Satışlar alındı • ${daily.length} günlük kayıt');}catch(e){notice('Satışlar alınamadı: $e');}finally{if(mounted)setState(()=>busy=false);}}
 Future<void> refreshKasa()async{setState(()=>busy=true);try{final k=await api('/kasa?date=${day(selected)}');setState(()=>kasa=k);try{await refreshSales();}catch(_){ }notice('Kasa verileri yenilendi');}catch(e){notice('Kasa alınamadı: $e');}finally{if(mounted)setState(()=>busy=false);}}
 double remaining(Map<String,dynamic> p){final id='${p['id']}';return number(base[id]).toDouble()-max(0,number(previousSales[id])-number(map(jsonDecode(prefs?.getString('stockBaselineSales')??'{}'))[id])).toDouble();}
 bool fuel(Map<String,dynamic> p){if(fuelIds.split(',').map((e)=>e.trim()).contains('${p['id']}'))return true;final name='${p['name']}'.toLowerCase();return ['dizel','diesel','benzin','benz','gorivo','fuel','eurodizel'].any(name.contains);}
 String barcode(Map<String,dynamic> p){final b=list(p['barcodes']);return b.isEmpty?'':'${b.first}';}
 Map<String,dynamic>? findBarcode(String code){for(final p in products){if(list(p['barcodes']).any((e)=>'$e'==code))return p;}return null;}

 Future<void> recordBarcodeError(String code)async{
  final key=code.trim();if(key.isEmpty)return;
  setState(()=>barcodeErrors[key]={'barcode':key,'date':DateTime.now().toIso8601String(),'status':'Bekliyor'});
  await save();notice('Barkod hatası kaydedildi: $key');
 }
 Future<void> editBarcodeError(String code)async{
  final ctrl=TextEditingController(text:'${map(barcodeErrors[code])['status']??'Bekliyor'}');
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text('Barkod: $code'),content:TextField(controller:ctrl,decoration:const InputDecoration(labelText:'Durum / açıklama')),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('İptal')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Kaydet'))]));
  if(ok==true){setState(()=>barcodeErrors[code]={...map(barcodeErrors[code]),'status':ctrl.text.trim()});await save();}
 }
 Widget barcodeErrorsPage()=>ListView(children:[card('Barkod Hataları',Column(children:[for(final e in barcodeErrors.entries)ListTile(title:Text(e.key),subtitle:Text('${map(e.value)['status']??''}'),onTap:()=>editBarcodeError(e.key),trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>confirmClear('Barkod hatasını sil?',()=>barcodeErrors.remove(e.key)))),if(barcodeErrors.isEmpty)const Text('Kayıt yok'),action('Barkod Hataları Excel',Icons.file_download,()=>exportCsv('SSOIL_BARKOD_HATALARI',[['Barkod','Tarih','Durum'],...barcodeErrors.entries.map((e)=>[e.key,map(e.value)['date'],map(e.value)['status']])]))]),icon:Icons.qr_code),action('Barkod hatalarını temizle',Icons.delete_sweep,()=>confirmClear('Tüm barkod hataları silinsin mi?',()=>barcodeErrors.clear()))]);
 Future<void> scanCount()async{await Navigator.push(context,MaterialPageRoute(builder:(c)=>Scanner(onCode:(code){Navigator.pop(c);final p=findBarcode(code);if(p==null){recordBarcodeError(code);return;}addDiscrepancy('sayim',product:p);})));}
 Future<void> scan({bool order=false})async{await Navigator.push(context,MaterialPageRoute(builder:(c)=>Scanner(onCode:(code){Navigator.pop(c);final p=findBarcode(code);if(p==null){recordBarcodeError(code);return;}if(order){addOrder(p);}else{productDetail(p);}})));}
 void addOrder(Map<String,dynamic> p){final id='${p['id']}';final sid='${supplierOf[id]??''}';setState((){orders[id]=number(orders[id])+1;orderUnits.putIfAbsent(id,()=> 'KOM');});save();notice('${p['name']} siparişe eklendi${sid.isEmpty?' • Tedarikçi tanımla':''}');}
 Future<void> confirmClear(String title,VoidCallback onClear)async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(title),content:const Text('Bu listedeki kayıtlar temizlensin mi? Bu işlem geri alınamaz.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('İptal')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Temizle'))]));if(ok==true){setState(onClear);await save();notice(pending.isEmpty?'Temizleme PC ile eşitlendi':'Temizleme telefonda kaydedildi; PC onayı bekleniyor (${pending.length})');}}
 Map<String,dynamic>? byId(String id){for(final p in products){if('${p['id']}'==id)return p;}return null;}
 Future<void> exportCsv(String filename,List<List<dynamic>> rows)async{
  final book=xl.Excel.createExcel(); final sheet=book['Rapor'];
  for(final row in rows){sheet.appendRow(row.map((v)=>v is num?xl.DoubleCellValue(v.toDouble()):xl.TextCellValue('$v')).toList());}
  book.setDefaultSheet('Rapor'); final bytes=book.encode();if(bytes==null){notice('Excel oluşturulamadı');return;}
  await deliverExcel('$filename.xlsx',bytes);
 }
 Future<void> deliverExcel(String filename,List<int> bytes)async{
  final option=await showModalBottomSheet<String>(context:context,builder:(c)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[ListTile(leading:const Icon(Icons.save_alt),title:const Text('Telefona Kaydet'),onTap:()=>Navigator.pop(c,'save')),ListTile(leading:const Icon(Icons.share),title:const Text('Paylaş'),onTap:()=>Navigator.pop(c,'share'))])));
  if(option=='save'){
   try{final path=await FilePicker.platform.saveFile(dialogTitle:'Excel dosyasını kaydet',fileName:filename,type:FileType.custom,allowedExtensions:['xlsx'],bytes:Uint8List.fromList(bytes));if(path!=null)notice('Excel kaydedildi');}
   catch(e){notice('Kaydetme başarısız: $e');}
  }else if(option=='share'){
   final dir=await getTemporaryDirectory();final f=File('${dir.path}/$filename');await f.writeAsBytes(bytes);await Share.shareXFiles([XFile(f.path)],text:filename);
  }
 }
 Future<void> exportProducts()async{await exportCsv('SSOIL_TUM_URUNLER',[['Ürün kodu','Ürün adı','Barkod','Stok','Fiyat KM'],...products.map((p)=>[p['id'],p['name'],barcode(p),remaining(p),p['price']])]);}
 Future<void> exportOrders([String? onlySupplier])async{
  if(orders.isEmpty){notice('Sipariş listesi boş');return;}
  final book=xl.Excel.createExcel();
  final grouped=<String,List<String>>{};
  for(final id in orders.keys){final sid='${supplierOf[id]??''}';if(onlySupplier!=null&&sid!=onlySupplier)continue;grouped.putIfAbsent(sid,()=>[]).add(id);}
  for(final entry in grouped.entries){
   final name='${map(suppliers[entry.key])['name']??'TEDARIKCISIZ'}';
   final sheet=book[name.replaceAll(RegExp(r'[\\/*?:\[\]]'),'_').substring(0,min(31,name.length))];
   final rows=<List<dynamic>>[['Barkod','Ürün adı','Miktar','Birim (KOM/PAK)','Ürün kodu'],for(final id in entry.value)[barcode(byId(id)??{}),byId(id)?['name']??id,orders[id],orderUnits[id]??'KOM',id]];
   for(final row in rows){sheet.appendRow(row.map((v)=>v is num?xl.DoubleCellValue(v.toDouble()):xl.TextCellValue('$v')).toList());}
  }
  book.delete('Sheet1');final bytes=book.encode();if(bytes!=null)await deliverExcel('SSOIL_SIPARISLER.xlsx',bytes);
 }
 Future<void> exportAll()async{
  final book=xl.Excel.createExcel();
  void add(String name,List<List<dynamic>> rows){final sheet=book[name];for(final row in rows){sheet.appendRow(row.map((v)=>v is num?xl.DoubleCellValue(v.toDouble()):xl.TextCellValue('$v')).toList());}}
  add('Stok',[['Kod','Ürün','Barkod','Stok','Fiyat'],...products.map((p)=>[p['id'],p['name'],barcode(p),remaining(p),p['price']])]);
  add('Siparişler',[['Kod','Ürün','Tedarikçi','Miktar','Birim'],...orders.entries.map((e)=>[e.key,byId(e.key)?['name']??'',map(suppliers['${supplierOf[e.key]??''}'])['name']??'',e.value,orderUnits[e.key]??'KOM'])]);
  add('Eksik Fazla',[['Kod','Sistem','Sayılan','Fark'],...discrepancies.values.map((v){final d=map(v);return [d['product_id'],d['system_stock'],d['counted_stock'],d['difference']];})]);
  add('Etiketler',[['Kod','Ürün','Barkod','Fiyat'],...labels.values.map((v){final p=map(v);return [p['id'],p['name'],barcode(p),p['price']];})]);
  add('Barkod Hataları',[['Barkod','Tarih','Durum'],...barcodeErrors.entries.map((e)=>[e.key,map(e.value)['date'],map(e.value)['status']])]);
  add('Tedarikçiler',[['Firma','Telefon'],...suppliers.values.map((v)=>[map(v)['name'],map(v)['phone']])]);
  book.delete('Sheet1');final bytes=book.encode();if(bytes!=null)await deliverExcel('SSOIL_TUM_RAPORLAR.xlsx',bytes);
 }
 Future<void> exportDiscrepancies()async{await exportCsv('SSOIL_EKSIK_FAZLA',[['Ürün kodu','Ürün adı','Barkod','Sistem stoku','Sayılan stok','Fark','Açıklama','Tarih'],...discrepancies.values.map((v){final d=map(v),p=byId('${d['product_id']}')??{};return [d['product_id'],p['name']??'',barcode(p),d['system_stock']??'',d['counted_stock']??'',d['difference']??0,d['note']??'',d['date']??''];})]);}
 Future<void> addDiscrepancy(String kind,{Map<String,dynamic>? product})async{
  final code=TextEditingController(text:product==null?'':'${product['id']}'),qty=TextEditingController(),note=TextEditingController();
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Stok Sayımı'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:code,decoration:const InputDecoration(labelText:'Ürün kodu veya barkod')),const SizedBox(height:8),TextField(controller:qty,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Sayılan toplam stok')),const SizedBox(height:8),TextField(controller:note,decoration:const InputDecoration(labelText:'Açıklama'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('İptal')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Kaydet'))]));
  if(ok!=true)return;final p=product??findBarcode(code.text)??byId(code.text.trim());final counted=num.tryParse(qty.text.replaceAll(',','.'));
  if(p==null||counted==null||counted<0){notice('Geçerli ürün ve sayılan stok gir');return;}
  final system=remaining(p);final difference=counted-system;
  final id='${p['id']}';final data={'product_id':id,'system_stock':system,'counted_stock':counted,'difference':difference,'note':note.text,'date':DateTime.now().toIso8601String()};
  setState(()=>discrepancies[id]=data);await save();notice('Stok farkı: ${difference>0?'+':''}$difference');
 }
 Widget countPage()=>ListView(children:[card('Stok Sayım / Eksik - Fazla',Column(children:[Wrap(spacing:8,runSpacing:8,children:[action('Barkod Oku',Icons.qr_code_scanner,scanCount),action('Sayım Gir',Icons.fact_check,()=>addDiscrepancy('sayim')),action('Tüm Ürünler Excel',Icons.file_download,exportProducts),action('Eksik/Fazla Excel',Icons.table_view,exportDiscrepancies)]),const SizedBox(height:8),for(final e in discrepancies.entries)ListTile(title:Text("${byId('${map(e.value)['product_id']}')?['name']??map(e.value)['product_id']}"),subtitle:Text('Sistem: ${map(e.value)['system_stock']} • Sayılan: ${map(e.value)['counted_stock']}'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text('${number(map(e.value)['difference'])>0?'+':''}${map(e.value)['difference']}',style:const TextStyle(color:gold,fontWeight:FontWeight.bold)),IconButton(icon:const Icon(Icons.close),onPressed:()=>confirmClear('Bu kaydı sil?',(){discrepancies.remove(e.key);}))])),OutlinedButton.icon(onPressed:()=>confirmClear('Eksik/Fazla listesini temizle?',()=>discrepancies.clear()),icon:const Icon(Icons.delete_sweep),label:const Text('Listeyi temizle'))]),icon:Icons.fact_check)]);

 Future<void> addPhoto(Map<String,dynamic> p,ImageSource src)async{final img=await ImagePicker().pickImage(source:src,imageQuality:70,maxWidth:1000);if(img==null)return;final dir=await getApplicationDocumentsDirectory();final f=await File(img.path).copy('${dir.path}/ssoil_${p['id']}.jpg');setState(()=>photos['${p['id']}']=f.path);await save();}
 void productDetail(Map<String, dynamic> p) {
   final id = '${p['id']}';
   showDialog<void>(
     context: context,
     barrierDismissible: true,
     builder: (dialogContext) => LayoutBuilder(
       builder: (dialogContext, constraints) {
         final keyboardHeight = MediaQuery.of(dialogContext).viewInsets.bottom;
         return Dialog(
           backgroundColor: panel,
           insetPadding: EdgeInsets.fromLTRB(12, 12, 12, 12 + keyboardHeight),
           child: SizedBox(
             width: double.infinity,
             height: constraints.maxHeight - 24 - keyboardHeight,
             child: StatefulBuilder(
               builder: (innerContext, update) => Column(
                 children: [
                   Padding(
                     padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                     child: Row(children: [
                       Expanded(child: Text('${p['name']}', maxLines: 2,
                         overflow: TextOverflow.ellipsis,
                         style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                       IconButton(icon: const Icon(Icons.close),
                         tooltip: 'Kapat',
                         onPressed: () => Navigator.pop(innerContext)),
                     ]),
                   ),
                   Expanded(
                     child: SingleChildScrollView(
                       keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                       padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           photo(id, 100),
                           const SizedBox(height: 8),
                           Text('Šifra: $id  •  Barkod: ${barcode(p)}'),
                           Text('Cijena: ${money(p['price'])} KM'),
                           Text('Tahmini kalan stok: ${money(remaining(p))}'),
                           const SizedBox(height: 8),
                           OutlinedButton.icon(
                             onPressed: () { Navigator.pop(innerContext); setMinimum(p); },
                             icon: const Icon(Icons.tune),
                             label: Text('Kritik stok seviyesi: ${minimum[id] ?? 'Tanımsız'}'),
                           ),
                           const SizedBox(height: 12),
                           Wrap(spacing: 8, runSpacing: 8, children: [
                             action('Kamera', Icons.camera_alt, () async { await addPhoto(p, ImageSource.camera); update(() {}); }),
                             action('Galeri', Icons.image, () async { await addPhoto(p, ImageSource.gallery); update(() {}); }),
                             action('Fotoğrafı sil', Icons.delete_outline, () { setState(() => photos.remove(id)); save(); update(() {}); }),
                             action('Etiket Yok', Icons.label_off, () { setState(() => labels[id] = p); save(); notice('Etiket listesine eklendi'); }),
                             action('Siparişe ekle', Icons.add_shopping_cart, () { addOrder(p); }),
                             action('Tedarikçi seç', Icons.store, () { Navigator.pop(innerContext); assignSupplier(p); }),
                             action('Eksik', Icons.trending_down, () { Navigator.pop(innerContext); addDiscrepancy('eksik', product:p); }),
                             action('Fazla', Icons.trending_up, () { Navigator.pop(innerContext); addDiscrepancy('fazla', product:p); }),
                           ]),
                         ],
                       ),
                     ),
                   ),
                 ],
               ),
             ),
           ),
         );
       },
     ),
   );
 }
 void setMinimum(Map<String,dynamic> p){final t=TextEditingController(text:'${minimum['${p['id']}']??''}');showDialog(context:context,builder:(c)=>AlertDialog(title:Text('${p['name']} • Minimum stok'),content:TextField(controller:t,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Kritik seviye')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('İptal')),FilledButton(onPressed:(){setState(()=>minimum['${p['id']}']=number(t.text));save();Navigator.pop(c);},child:const Text('Kaydet'))]));}
 void assignSupplier(Map<String,dynamic> p){showDialog(context:context,builder:(c)=>AlertDialog(title:Text('${p['name']} • Tedarikçi'),content:SizedBox(width:300,child:Column(mainAxisSize:MainAxisSize.min,children:[for(final e in suppliers.entries)ListTile(title:Text('${map(e.value)['name']}'),onTap:(){setState(()=>supplierOf['${p['id']}']=e.key);save();Navigator.pop(c);}),ListTile(title:const Text('Yeni tedarikçi ekle'),leading:const Icon(Icons.add),onTap:(){Navigator.pop(c);addSupplier();})])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Kapat'))]));}
 void addSupplier(){final name=TextEditingController(),phone=TextEditingController();showDialog(context:context,builder:(c)=>AlertDialog(title:const Text('Tedarikçi ekle'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Firma adı')),const SizedBox(height:8),TextField(controller:phone,decoration:const InputDecoration(labelText:'Telefon'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('İptal')),FilledButton(onPressed:(){if(name.text.trim().isEmpty)return;final id=DateTime.now().microsecondsSinceEpoch.toString();setState(()=>suppliers[id]={'name':name.text.trim(),'phone':phone.text.trim()});save();Navigator.pop(c);},child:const Text('Kaydet'))]));}
 Widget photo(String id,double size){final path='${photos[id]??''}';return Container(width:size,height:size,decoration:BoxDecoration(color:const Color(0xff253143),borderRadius:BorderRadius.circular(14)),clipBehavior:Clip.antiAlias,child:path.isNotEmpty&&File(path).existsSync()?Image.file(File(path),fit:BoxFit.cover):const Icon(Icons.inventory_2_outlined,color:gold));}
 Widget action(String label,IconData icon,VoidCallback f)=>OutlinedButton.icon(onPressed:f,icon:Icon(icon,size:18),label:Text(label));
 Widget card(String title,Widget child,{IconData icon=Icons.dashboard})=>Card(margin:const EdgeInsets.only(bottom:12),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(icon,color:gold),const SizedBox(width:8),Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w700))]),const SizedBox(height:12),child])));
 Widget metric(String a,String b)=>Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Expanded(child:Text(a)),Text(b,style:const TextStyle(color:gold,fontWeight:FontWeight.bold))]));
 Widget homePage()=>ListView(children:[card('Hızlı işlemler',Wrap(spacing:9,runSpacing:9,children:[action('Barkod Oku',Icons.qr_code_scanner,()=>scan()),action('Stok Güncelle',Icons.sync,refreshStock),action('Kasa',Icons.point_of_sale,(){setState(()=>page=1);}),action('Siparişe Tara',Icons.add_shopping_cart,()=>scan(order:true)),action('Stok Sayım',Icons.fact_check,(){setState(()=>page=7);}),action('Barkod Hataları',Icons.report_problem_outlined,(){setState(()=>page=8);})]),icon:Icons.bolt),card('SS OIL',Column(children:[metric('Ürün sayısı','${products.length}'),metric('Etiket bekleyen','${labels.length}'),metric('Sipariş kalemi','${orders.length}'),metric('Bağlantı',source)]))]);
 double salesTotal(bool isFuel){final counts=map(daily[day(selected)]);double total=0;for(final p in products){if(fuel(p)==isFuel)total+=number(counts['${p['id']}']).toDouble()*number(p['price']).toDouble();}return total;}
 Widget kasaPage()=>ListView(children:[Row(children:[Expanded(child:Text('Tarih: ${day(selected)}')),IconButton(onPressed:()async{final d=await showDatePicker(context:context,initialDate:selected,firstDate:DateTime(2020),lastDate:DateTime(2100));if(d!=null)setState(()=>selected=d);},icon:const Icon(Icons.calendar_month)),FilledButton.icon(onPressed:refreshKasa,icon:const Icon(Icons.refresh),label:const Text('Güncelle'))]),card('Tahsilatlar',Column(children:[metric('Nakit (Dopuna dahil)',kasa['cash']==null?'Veri yok':'${money(kasa['cash'])} KM'),metric('Kredi kartı',kasa['card']==null?'Veri yok':'${money(kasa['card'])} KM'),metric('MTEL Dopuna',kasa['mtel_dopuna']==null?'Veri yok':'${money(kasa['mtel_dopuna'])} KM'),metric('AERO Dopuna',kasa['aero_dopuna']==null?'Veri yok':'${money(kasa['aero_dopuna'])} KM'),metric('Toplam nakit + kart',kasa['cash']==null?'Dopuna doğrulanamadı':'${money(number(kasa['cash'])+number(kasa['card']))} KM')]),icon:Icons.payments),card('Satış grupları',Column(children:[metric('Yakıt',daily.containsKey(day(selected))?'${money(salesTotal(true))} KM':'Satış kaydı yok'),metric('Market',daily.containsKey(day(selected))?'${money(salesTotal(false))} KM':'Satış kaydı yok'),metric('Toplam Yakıt + Market',daily.containsKey(day(selected))?'${money(salesTotal(true) + salesTotal(false))} KM':'Satış kaydı yok')]),icon:Icons.storefront),card('Yakıt stokları',Column(children:[for(final p in products.where(fuel).take(20))metric('${p['name']}',base.containsKey('${p['id']}')?'${money(remaining(p))} L':'Başlangıç stoku yok')]),icon:Icons.local_gas_station)]);
 Widget stockPage(){final q=search.text.toLowerCase();final filtered=products.where((p)=>'${p['name']} ${p['id']} ${barcode(p)}'.toLowerCase().contains(q)&&(stockSupplier=='all'||(stockSupplier=='none'?'${supplierOf['${p['id']}']??''}'.isEmpty:'${supplierOf['${p['id']}']??''}'==stockSupplier))).toList();return Column(children:[Row(children:[Expanded(child:TextField(controller:search,onChanged:(_)=>setState((){}),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Ürün, şifra veya barkod'))),IconButton(onPressed:()=>scan(),icon:const Icon(Icons.qr_code_scanner))]),const SizedBox(height:8),DropdownButtonFormField<String>(value:stockSupplier,isExpanded:true,decoration:const InputDecoration(labelText:'Tedarikçiye göre filtrele'),items:[const DropdownMenuItem(value:'all',child:Text('Tüm tedarikçiler')),const DropdownMenuItem(value:'none',child:Text('Tedarikçisi olmayanlar')),...suppliers.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text('${map(e.value)['name']}')))],onChanged:(v)=>setState(()=>stockSupplier=v??'all')),const SizedBox(height:8),Row(children:[Expanded(child:FilledButton.icon(onPressed:refreshStock,icon:const Icon(Icons.sync),label:const Text('Stok Güncelle')))]),Expanded(child:ListView.builder(itemCount:filtered.length,itemBuilder:(c,i){final p=filtered[i];return Card(child:ListTile(onTap:()=>productDetail(p),leading:photo('${p['id']}',48),title:Text('${p['name']}',maxLines:2),subtitle:Text('Šifra: ${p['id']} • Cijena: ${money(p['price'])} KM'),trailing:Text('${money(remaining(p))}\nKalan',textAlign:TextAlign.end)));}))]);}
 String stockSupplier='all';
 final search=TextEditingController();
 void supplierOrdersPage(String supplierId){
   final supplierName=supplierId.isEmpty?'Tedarikçisi tanımlanmayanlar':'${map(suppliers[supplierId])['name']??'Tedarikçi'}';
   showDialog<void>(context:context,builder:(routeContext)=>Dialog(backgroundColor:panel,insetPadding:const EdgeInsets.symmetric(horizontal:12,vertical:30),child:ConstrainedBox(constraints:BoxConstraints(maxHeight:MediaQuery.of(routeContext).size.height*0.85),child:StatefulBuilder(builder:(routeContext,update){
     final ids=orders.keys.where((id)=>'${supplierOf[id]??''}'==supplierId).toList();
     return ListView(shrinkWrap:true,padding:const EdgeInsets.all(12),children:[Text(supplierName,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),const SizedBox(height:12),
       for(final id in ids)Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
         Text('${products.where((p)=>'${p['id']}'==id).firstOrNull?['name']??id}',style:const TextStyle(fontWeight:FontWeight.bold)),
         const SizedBox(height:6),Text('Šifra: $id • Barkod: ${products.where((p)=>'${p['id']}'==id).firstOrNull==null?'':barcode(products.firstWhere((p)=>'${p['id']}'==id))}'),
         Row(children:[PopupMenuButton<String>(tooltip:'KOM / PAK',onSelected:(v){setState(()=>orderUnits[id]=v);update((){});save();},itemBuilder:(c)=>[const PopupMenuItem(value:'KOM',child:Text('KOM')),const PopupMenuItem(value:'PAK',child:Text('PAK'))],child:Padding(padding:const EdgeInsets.all(8),child:Text('${orderUnits[id]??'KOM'} ▾'))),
           const Spacer(),IconButton(tooltip:'Azalt',onPressed:(){setState((){final q=number(orders[id]);if(q>1){orders[id]=q-1;}else{orders.remove(id);orderUnits.remove(id);}});update((){});save();},icon:const Icon(Icons.remove_circle_outline)),Text('${orders[id]??0}'),IconButton(tooltip:'Artır',onPressed:(){setState(()=>orders[id]=number(orders[id])+1);update((){});save();},icon:const Icon(Icons.add_circle_outline)),IconButton(tooltip:'Sil',onPressed:(){setState((){orders.remove(id);orderUnits.remove(id);});update((){});save();},icon:const Icon(Icons.delete_outline))])
       ]))),
       if(ids.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Text('Bu tedarikçi için sipariş bulunmuyor.')),
       action('Bu tedarikçinin Exceli',Icons.file_download,()=>exportOrders(supplierId)),
       action('Bu tedarikçinin siparişlerini temizle',Icons.delete_sweep,()async{
         await confirmClear('Bu tedarikçinin siparişleri PC merkezinden de silinsin mi?',(){
           for(final id in List<String>.from(ids)){orders.remove(id);orderUnits.remove(id);}
         });
         update((){});
       }),
     ]);
   }))));
 }
 Widget ordersPage(){
   final grouped=<String,int>{};for(final id in orders.keys){final sid='${supplierOf[id]??''}';grouped[sid]=(grouped[sid]??0)+1;}
   return ListView(children:[
     Wrap(spacing:8,runSpacing:8,children:[action('Tedarikçi ekle',Icons.add_business,addSupplier),action('Barkodla ekle',Icons.qr_code_scanner,()=>scan(order:true)),action('Kritik stoktan ekle',Icons.warning_amber,(){int n=0;for(final p in products){final id='${p['id']}';if(minimum.containsKey(id)&&remaining(p)<=number(minimum[id])){orders[id]=max(1,number(minimum[id])-remaining(p));n++;}}setState((){});save();notice('$n ürün eklendi');})]),
     const SizedBox(height:10),card('Tedarikçiler',Column(children:[
       for(final e in suppliers.entries)ListTile(leading:const Icon(Icons.business),title:Text('${map(e.value)['name']}'),subtitle:Text('${grouped[e.key]??0} sipariş kalemi'),trailing:const Icon(Icons.chevron_right),onTap:()=>supplierOrdersPage(e.key)),
       if(grouped.containsKey(''))ListTile(title:const Text('Tedarikçisi tanımlanmayanlar'),subtitle:Text('${grouped['']} sipariş kalemi'),trailing:const Icon(Icons.chevron_right),onTap:()=>supplierOrdersPage('')),
     ]),icon:Icons.business),
     Wrap(spacing:8,runSpacing:8,children:[action('Tedarikçiye göre Excel',Icons.file_download,()=>exportOrders()),action('Siparişleri temizle',Icons.delete_sweep,()=>confirmClear('Siparişleri temizle?',(){orders.clear();orderUnits.clear();}))]),
     card('Kritik stok ayarı',const Text('Ürün detayında minimum stok seviyesini belirleyebilir, ardından kritik stokları siparişe ekleyebilirsiniz.'),icon:Icons.warning_amber)
   ]);
 }
 Widget topPage(){final totals=<String,num>{};for(final d in daily.values){for(final e in map(d).entries){totals[e.key]=(totals[e.key]??0)+number(e.value);}}final sorted=products.where((p)=>!fuel(p)&&totals.containsKey('${p['id']}')).toList()..sort((a,b)=>number(totals['${b['id']}']).compareTo(number(totals['${a['id']}'])));return Column(children:[Row(children:[Expanded(child:Text('Son ${daily.length} gün • Akaryakıt hariç ilk 100')),FilledButton.icon(onPressed:refreshSales,icon:const Icon(Icons.refresh),label:const Text('Güncelle'))]),Expanded(child:ListView.builder(itemCount:min(100,sorted.length),itemBuilder:(c,i){final p=sorted[i];return Card(child:ListTile(leading:photo('${p['id']}',48),title:Text('${i+1}. ${p['name']}'),subtitle:Text('Šifra: ${p['id']}'),trailing:Text('${money(totals['${p['id']}'])} adet')));} ))]);}
 String labelMode='custom';
 double labelWidthMm=38,labelHeightMm=25,labelGapMm=0,labelMarginMm=0;

 Future<void> editLabelDimensions()async{
  final w=TextEditingController(text:'$labelWidthMm'),h=TextEditingController(text:'$labelHeightMm'),m=TextEditingController(text:'$labelMarginMm');
  final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Etiket ölçüleri (mm)'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:w,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Genişlik (mm)')),TextField(controller:h,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Yükseklik (mm)')),TextField(controller:m,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'İç boşluk (mm)'))])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('İptal')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Uygula'))]));
  if(ok!=true)return;final nw=double.tryParse(w.text.replaceAll(',','.')),nh=double.tryParse(h.text.replaceAll(',','.')),nm=double.tryParse(m.text.replaceAll(',','.'));
  if(nw==null||nh==null||nm==null||nw<20||nh<15||nw>210||nh>297||nm<0||nm>5){notice('Geçerli ölçüler gir (mm)');return;}
  setState((){labelWidthMm=nw;labelHeightMm=nh;labelMarginMm=nm;labelMode='custom';});
 }
 Future<void> printLabels()async{
  if(labels.isEmpty){notice('Etiket listesi boş');return;}
  pw.Widget labelWidget(Map<String,dynamic> item)=>pw.Container(padding:const pw.EdgeInsets.all(3),child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,mainAxisAlignment:pw.MainAxisAlignment.center,children:[pw.Text('${item['name']}',maxLines:2,style:pw.TextStyle(fontSize:7,fontWeight:pw.FontWeight.bold)),pw.Text('Sifra: ${item['id']}',style:const pw.TextStyle(fontSize:6)),pw.Text('Cijena: ${money(item['price'])} KM',style:const pw.TextStyle(fontSize:7)),if(barcode(item).isNotEmpty)...[pw.BarcodeWidget(barcode:pw.Barcode.code128(),data:barcode(item),height:8,drawText:false),pw.Center(child:pw.Text(barcode(item),style:const pw.TextStyle(fontSize:7)))]]));
  final pdf=pw.Document();final items=labels.values.map((e)=>map(e)).toList();
  if(labelMode=='sheet9'){for(var start=0;start<items.length;start+=9){final chunk=items.skip(start).take(9).toList();pdf.addPage(pw.Page(pageFormat:PdfPageFormat(114*PdfPageFormat.mm,75*PdfPageFormat.mm),margin:pw.EdgeInsets.zero,build:(c)=>pw.Wrap(spacing:0,runSpacing:0,children:[for(final item in chunk)pw.SizedBox(width:38*PdfPageFormat.mm,height:25*PdfPageFormat.mm,child:labelWidget(item))])));}}else if(labelMode=='a4'){
   for(var start=0;start<items.length;start+=40){final chunk=items.skip(start).take(40).toList();pdf.addPage(pw.Page(pageFormat:PdfPageFormat.a4,margin:const pw.EdgeInsets.all(18),build:(c)=>pw.Wrap(spacing:4,runSpacing:4,children:[for(final item in chunk)pw.Container(width:38*PdfPageFormat.mm,height:25*PdfPageFormat.mm,child:labelWidget(item))])));}
  }else{
   for(final item in items){pdf.addPage(pw.Page(pageFormat:PdfPageFormat(labelWidthMm*PdfPageFormat.mm,labelHeightMm*PdfPageFormat.mm),margin:pw.EdgeInsets.all(labelMarginMm*PdfPageFormat.mm),build:(c)=>labelWidget(item)));}
  }
  final dir=await getTemporaryDirectory();final f=File('${dir.path}/SSOIL_etiketler.pdf');await f.writeAsBytes(await pdf.save());await Share.shareXFiles([XFile(f.path)]);
 }

 Widget reportsPage()=>ListView(children:[card('Etiket yazdırma',Column(children:[for(final e in labels.entries)ListTile(title:Text('${map(e.value)['name']}'),subtitle:Text('Šifra: ${e.key} • Cijena: ${money(map(e.value)['price'])} KM'),trailing:IconButton(onPressed:(){setState(()=>labels.remove(e.key));save();},icon:const Icon(Icons.close)))] ,),icon:Icons.label),card('Etiket kağıdı',Column(children:[RadioListTile<String>(title:const Text('A4'),value:'a4',groupValue:labelMode,onChanged:(v)=>setState(()=>labelMode=v!)),RadioListTile<String>(title:const Text('9 etiketli sayfa • 3 × 3'),value:'sheet9',groupValue:labelMode,onChanged:(v)=>setState(()=>labelMode=v!)),RadioListTile<String>(title:Text('Özel ölçü • ${labelWidthMm.toStringAsFixed(0)} × ${labelHeightMm.toStringAsFixed(0)} mm'),value:'custom',groupValue:labelMode,onChanged:(v)=>setState(()=>labelMode=v!)),action('Özel ölçüyü ayarla',Icons.tune,editLabelDimensions)]),icon:Icons.print),FilledButton.icon(onPressed:printLabels,icon:const Icon(Icons.print),label:const Text('Etiket PDF oluştur')),const SizedBox(height:12),card('Excel Raporları',Wrap(spacing:8,runSpacing:8,children:[action('Tümünü Excel’e Aktar',Icons.file_download,exportAll),action('Tüm Ürünler',Icons.table_view,exportProducts),action('Siparişler (Tedarikçiye göre)',Icons.file_download,()=>exportOrders()),action('Eksik / Fazla',Icons.fact_check,exportDiscrepancies),action('Tedarikçiler',Icons.business,()=>exportCsv('SSOIL_TEDARIKCILER',[['Tedarikçi','Telefon'],...suppliers.values.map((e)=>[map(e)['name'],map(e)['phone']])])),action('Barkod Hataları',Icons.qr_code,()=>exportCsv('SSOIL_BARKOD_HATALARI',[['Barkod','Tarih','Durum'],...barcodeErrors.entries.map((e)=>[e.key,map(e.value)['date'],map(e.value)['status']])])),action('Etiket Listesi',Icons.label,()=>exportCsv('SSOIL_ETIKETLER',[['Kod','Ürün','Barkod','Fiyat'],...labels.values.map((v){final p=map(v);return [p['id'],p['name'],barcode(p),p['price']];})]))]),icon:Icons.file_download),card('Satış kayıtları',Column(children:[for(final d in (daily.keys.toList()..sort()).reversed)metric(d,'${map(daily[d]).length} ürün')]),icon:Icons.bar_chart)]);
 Future<void> testSupabase()async{
  final url=supabaseUrl.trim().replaceAll(RegExp(r'/+$'),'');
  if(!url.startsWith('https://')||supabaseKey.trim().isEmpty){setState(()=>cloudStatus='URL veya publishable key eksik');return;}
  setState(()=>cloudStatus='Bağlantı test ediliyor...');
  try{
   final response=await http.get(Uri.parse('$url/auth/v1/health'),headers:{'apikey':supabaseKey.trim()}).timeout(const Duration(seconds:10));
   if(!mounted)return;
   setState(()=>cloudStatus=response.statusCode==200?'Supabase erişilebilir (veri eşitleme doğrulanmadı)':'Supabase yanıtı: HTTP ${response.statusCode}');
  }catch(e){if(mounted)setState(()=>cloudStatus='Bağlantı başarısız: $e');}
 }
 // Shared settings input. Values are persisted by the existing Save actions.
 Widget field(String title, String value, ValueChanged<String> onChanged) {
  return Padding(
   padding: const EdgeInsets.only(bottom: 10),
   child: TextFormField(
    key: ValueKey('settings_$title'),
    initialValue: value,
    onChanged: onChanged,
    autocorrect: false,
    decoration: InputDecoration(labelText: title),
   ),
  );
 }

 Widget settingsPage()=>ListView(children:[
  card('Bağlantılar',Column(children:[
   field('Yerel API adresi',local,(v)=>local=v),
   field('Bulut API adresi (isteğe bağlı, SS OIL köprüsü)',cloud,(v)=>cloud=v),
   field('API erişim tokeni',token,(v)=>token=v),
   field('Coffee To Go bağlantısı (sonra)',coffeeUrl,(v)=>coffeeUrl=v),
   field('Yakıt Art_ID listesi (virgülle)',fuelIds,(v)=>fuelIds=v),
   FilledButton(onPressed:()async{await save();notice('Ayarlar kaydedildi');},child:const Text('Kaydet'))
  ]),icon:Icons.settings_ethernet),
  card('Supabase Bulut Bağlantısı',Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   const Text('PC ana merkezdir. Bu ayarlar yalnızca Supabase erişimini test eder; PC köprüsü ve telefon eşitlemesi ayrıca kurulmalıdır.'),
   const SizedBox(height:10),
   field('Supabase Project URL (https://...)',supabaseUrl,(v)=>supabaseUrl=v),
   field('Publishable / anon key (service_role DEĞİL)',supabaseKey,(v)=>supabaseKey=v),
   const SizedBox(height:8),
   Text(cloudStatus),
   const SizedBox(height:8),
   Wrap(spacing:8,runSpacing:8,children:[
    OutlinedButton.icon(onPressed:()async{await save();notice('Bulut ayarları telefona kaydedildi');},icon:const Icon(Icons.save),label:const Text('Kaydet')),
    FilledButton.icon(onPressed:testSupabase,icon:const Icon(Icons.cloud_done),label:const Text('Bağlantıyı Test Et')),
   ]),
  ]),icon:Icons.cloud_outlined),
  card('Veri Temizleme',Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   const Text('Silme öncesi onay alınır. PC bağlantısı başarısızsa silme değişikliği telefonda sıraya alınır; diğer cihazlara ulaştığı garanti değildir.'),
   const SizedBox(height:8),
   Wrap(spacing:8,runSpacing:8,children:[
    action('Etiketleri temizle',Icons.delete_sweep,()=>confirmClear('Etiketleri temizle?',()=>labels.clear())),
    action('Siparişleri temizle',Icons.delete_sweep,()=>confirmClear('Siparişleri temizle?',(){orders.clear();orderUnits.clear();})),
    action('Eksik/Fazla ve sayımı temizle',Icons.delete_sweep,()=>confirmClear('Eksik/Fazla ve sayım kayıtlarını temizle?',()=>discrepancies.clear())),
    action('Barkod hatalarını temizle',Icons.delete_sweep,()=>confirmClear('Barkod hatalarını temizle?',()=>barcodeErrors.clear())),
   ]),
   const SizedBox(height:8),
   const Text('Tedarikçi tanımları ve ürün–tedarikçi eşleşmeleri bu işlemlerle silinmez.'),
  ]),icon:Icons.delete_outline),
  card('Senkronizasyon Durumu',Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('PC bağlantısı: $source'),Text('Bekleyen değişiklik: ${pending.length}'),
   Text('Son alınan revizyon: $syncRevision'),
   const Text('PC /shared üzerinden otomatik kontrol 3 saniyede birdir. Supabase üzerinden çok telefonlu senkronizasyon henüz doğrulanmadı.'),
  ]),icon:Icons.sync),
 ]);

 @override Widget build(BuildContext c){final pages=[homePage(),kasaPage(),stockPage(),ordersPage(),topPage(),reportsPage(),settingsPage(),countPage(),barcodeErrorsPage()];final names=['Ana Sayfa','Kasa','Stok','Siparişler','Çok Satanlar','Raporlar','Ayarlar','Stok Sayım','Barkod Hataları'];final icons=[Icons.home_rounded,Icons.point_of_sale,Icons.inventory_2,Icons.shopping_cart,Icons.leaderboard,Icons.analytics,Icons.settings,Icons.fact_check,Icons.qr_code];return Scaffold(appBar:AppBar(title:Row(children:[ClipRRect(borderRadius:BorderRadius.circular(7),child:Image.asset('assets/ss_oil_logo.jpg',height:34,width:34,fit:BoxFit.contain)),const SizedBox(width:10),Text('SS OIL • ${names[page]}',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold))]),actions:[if(busy)const Padding(padding:EdgeInsets.all(14),child:SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))),IconButton(onPressed:()=>setState(()=>page=6),icon:const Icon(Icons.settings_outlined))]),body:Padding(padding:const EdgeInsets.all(12),child:pages[page]),bottomNavigationBar:NavigationBar(height:70,backgroundColor:panel,selectedIndex:page<5?page:0,onDestinationSelected:(i)=>setState(()=>page=i),destinations:[for(var i=0;i<5;i++)NavigationDestination(icon:Icon(icons[i]),label:names[i])]),drawer:Drawer(child:SafeArea(child:ListView(children:[DrawerHeader(child:Image.asset('assets/ss_oil_logo.jpg',fit:BoxFit.contain)),for(var i=0;i<names.length;i++)ListTile(leading:Icon(icons[i],color:page==i?gold:null),title:Text(names[i]),selected:page==i,onTap:(){setState(()=>page=i);Navigator.pop(c);})]))));}
}
class Scanner extends StatefulWidget{final ValueChanged<String> onCode;const Scanner({super.key,required this.onCode});@override State<Scanner> createState()=>_ScannerState();}
class _ScannerState extends State<Scanner>{bool scanned=false;@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Barkod Oku')),body:MobileScanner(onDetect:(capture){if(scanned)return;final code=capture.barcodes.firstOrNull?.rawValue;if(code!=null&&code.isNotEmpty){scanned=true;widget.onCode(code);}}));}
