import 'package:material_ui/material_ui.dart';

/// Dialog for entering a custom playback URL and optional HTTP headers.
Future<({String url, Map<String, String> headers})?> showCustomUrlDialog(
  BuildContext context,
) {
  return showDialog<({String url, Map<String, String> headers})>(
    context: context,
    builder: (context) => const _CustomUrlDialog(),
  );
}

class _CustomUrlDialog extends StatefulWidget {
  const _CustomUrlDialog();

  @override
  State<_CustomUrlDialog> createState() => _CustomUrlDialogState();
}

class _HeaderRow {
  _HeaderRow({String key = '', String value = ''})
      : keyController = TextEditingController(text: key),
        valueController = TextEditingController(text: value);

  final TextEditingController keyController;
  final TextEditingController valueController;

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

class _CustomUrlDialogState extends State<_CustomUrlDialog> {
  final _urlController = TextEditingController(
    text: 'https://',
  );
  final List<_HeaderRow> _headerRows = [_HeaderRow()];

  @override
  void dispose() {
    _urlController.dispose();
    for (final row in _headerRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addHeaderRow() {
    setState(() => _headerRows.add(_HeaderRow()));
  }

  void _removeHeaderRow(int index) {
    if (_headerRows.length <= 1) {
      _headerRows[index].keyController.clear();
      _headerRows[index].valueController.clear();
      return;
    }
    setState(() {
      _headerRows.removeAt(index).dispose();
    });
  }

  Map<String, String> _collectHeaders() {
    final headers = <String, String>{};
    for (final row in _headerRows) {
      final key = row.keyController.text.trim();
      final value = row.valueController.text.trim();
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      headers[key] = value;
    }
    return headers;
  }

  void _submit() {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入播放链接')),
      );
      return;
    }
    Navigator.of(context).pop((url: url, headers: _collectHeaders()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('自定义链接'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: '播放 URL',
                  hintText: 'https://example.com/video.mp4',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'HTTP 请求头',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addHeaderRow,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < _headerRows.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _headerRows[i].keyController,
                          decoration: const InputDecoration(
                            labelText: 'Header',
                            hintText: 'Referer',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _headerRows[i].valueController,
                          decoration: const InputDecoration(
                            labelText: 'Value',
                            hintText: 'https://example.com',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '删除',
                        onPressed: () => _removeHeaderRow(i),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('播放'),
        ),
      ],
    );
  }
}
