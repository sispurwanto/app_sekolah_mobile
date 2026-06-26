import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ManualBookScreen extends StatefulWidget {
  const ManualBookScreen({super.key});

  @override
  State<ManualBookScreen> createState() => _ManualBookScreenState();
}

class _ManualBookScreenState extends State<ManualBookScreen> {
  String _markdownContent = '';
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchMarkdown();
  }

  Future<void> _fetchMarkdown() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // 1. Ambil URL dari Firestore
      final doc = await FirebaseFirestore.instance.collection('manual_book').doc('manual_book').get();
      if (!doc.exists || !doc.data()!.containsKey('link')) {
        setState(() {
          _error = 'Gagal memuat: URL panduan belum diatur di sistem (Firestore).';
          _isLoading = false;
        });
        return;
      }

      final url = doc.data()!['link'] as String;
      if (url.isEmpty) {
        setState(() {
          _error = 'Gagal memuat: URL panduan kosong.';
          _isLoading = false;
        });
        return;
      }

      // 2. Ambil isi file markdown dari URL tersebut
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          _markdownContent = response.body;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Gagal memuat panduan (Status HTTP: ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Terjadi kesalahan: Periksa koneksi internet Anda atau pastikan URL valid.\n\nDetail: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buku Panduan'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat Ulang Panduan',
            onPressed: _fetchMarkdown,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchMarkdown,
                          child: const Text('Coba Lagi'),
                        )
                      ],
                    ),
                  ),
                )
              : _markdownContent.isEmpty
                  ? const Center(child: Text('Konten panduan kosong'))
                  : Markdown(
                      data: _markdownContent,
                      selectable: true,
                      onTapLink: (text, href, title) async {
                        if (href != null) {
                          final uri = Uri.parse(href);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                      styleSheet: MarkdownStyleSheet(
                        h1: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        h2: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        h3: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        p: const TextStyle(fontSize: 14),
                      ),
                    ),
    );
  }
}
