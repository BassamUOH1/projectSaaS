import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

List<String>title_a=[];
List<String>dese_a=[];
List<String>dueDate_a=[];
List<String>State_Completed_a=[];


// --------------------------  CREATE TABLE  --------------------------
Future<void> creatTableBigData(String tableName,String title ,String description,String dueDate , String finishOrNotFinish ,String data2,String data3,String data4) async{

  try {
    DateTime now = DateTime.now();

    String date =DateFormat("yyyy/MM/dd || hh:mm a").format(now);
    print("$tableName \n $date");
    // طباعة القيم للتأكد من إرسال البيانات بشكل صحيح
    print("إرسال البيانات: TableName=$tableName, PartitionKey=$title, SortKey=$description State_P=1");

    // إرسال طلب POST إلى Lambda
    final response = await http.post(
      Uri.parse('API'),
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Accept-Charset": "utf-8",
      },
      body: jsonEncode({
        "TableName": tableName,
        "id": title,          // ✘ كان: "ID" → ✔️ "id" (أحرف صغيرة)
        "name": description,      // ✘ كان: "Name" → ✔️ "name"
        "pass": dueDate,      // ✘ كان: "Pass" → ✔️ "pass"
        "Date": date,
        "Data_1":finishOrNotFinish,
        "Data_2":data2,
        "Data_3":data3,
        "Data_4":data4,
        "state_p": "5"     // ✘ كان: "State_P" → ✔️ "state_p"
      }),
    );

    // قراءة الرد وتفسيره
    final decodedBody = utf8.decode(response.bodyBytes);
    final jsonResponse = jsonDecode(decodedBody) as Map<String, dynamic>;

    print('كود الحالة: ${response.statusCode}');
    print('الرد: $jsonResponse');

  }catch (e, stackTrace) {
    print('حدث خطأ: ${e.toString()}');
    print('تفاصيل المكدس: $stackTrace');
    if (e is http.ClientException) {
      print("الرابط المُستخدم: ${e.uri}");
      print("الرسالة التفصيلية: ${e.message}");
    }
  }

}






Future<List<Map<String, dynamic>>> getall() async {
  const lambdaUrl = 'API';
  try {
    print("بدء استرجاع جميع البيانات من الجدول");

    final response = await http.post(
      Uri.parse(lambdaUrl),
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Accept-Charset": "utf-8",
      },
      body: jsonEncode({
        "TableName": "SaaS",
        "state_p": "4",
      }),
    );

    final decodedBody = utf8.decode(response.bodyBytes);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(decodedBody);
print(jsonList);
      // تنظيف المصفوفات قبل التعبئة
      title_a.clear();
      dese_a.clear();
      dueDate_a.clear();
      State_Completed_a.clear();

      // تعبئة المصفوفات الجديدة
      for (var item in jsonList) {
        final mapItem = Map<String, dynamic>.from(item as Map);

        title_a.add(mapItem['id']?.toString() ?? ''); // إذا كان 'id' يمثل العنوان
        dese_a.add(mapItem['name']?.toString() ?? ''); // إذا كان 'name' يمثل الوصف
        dueDate_a.add(mapItem['pass']?.toString() ?? ''); // إذا كان 'pass' يمثل التاريخ
        State_Completed_a.add(mapItem['Data_1']?.toString() ?? '');
      }
print("$title_a \n $dese_a \n $dueDate_a \ $State_Completed_a");
      return jsonList
          .map<Map<String, dynamic>>(
            (item) => Map<String, dynamic>.from(item as Map),
      )
          .toList();

    } else {
      final err = jsonDecode(decodedBody);
      throw Exception('فشل الاسترجاع: ${err["error"] ?? decodedBody}');
    }
  } catch (e) {
    print('حدث خطأ أثناء الاسترجاع: $e');
    rethrow;
  }
}


// ----------------------------  DELET ITEMS IN TABLE  -------------------------
Future<void> deleteItem(String tableName, String id) async {
  try {
    print("بدء عملية الحذف: TableName=$tableName, ID=$id");

    // إرسال طلب POST إلى Lambda مع State_P = 3
    final response = await http.post(
      Uri.parse('API'),
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Accept-Charset": "utf-8"
      },
      body: jsonEncode({
        "TableName": tableName,
        "id": id,
        "state_p": "3" // الحالة المخصصة للحذف
      }),
    );

    // معالجة الرد
    final decodedBody = utf8.decode(response.bodyBytes);
    final jsonResponse = jsonDecode(decodedBody) as Map<String, dynamic>;

    print('كود الحالة: ${response.statusCode}');

    if (response.statusCode == 200) {
      print('تم الحذف بنجاح: ${jsonResponse["message"]}');
    } else {
      print('فشل الحذف: ${jsonResponse["error"]}');
    }

  } catch (e) {
    print('حدث خطأ أثناء الحذف: ${e.toString()}');
  }
}