import 'package:http/http.dart' as http;
void main() async {
  final url = 'https://drive.google.com/uc?export=download&id=1ZTfvu0sYGAIPV-AL3oTYpJiGnDn34eA0';
  final response = await http.get(Uri.parse(url));
  print('Status: ${response.statusCode}');
  print('Body length: ${response.body.length}');
}
