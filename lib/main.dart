import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:file_picker/file_picker.dart';
import 'package:tester/firestore_services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_html/flutter_html.dart';

void main() {
  runApp(
    const MaterialApp(home: Editor()), // use MaterialApp
  );
}

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final customClaimsProvider = FutureProvider<dynamic>((ref) async {
  final user = ref.watch(authStateChangesProvider);

  if (user.value == null) {
    return {};
  }
  final idTokenResult = await FirebaseAuth.instance.currentUser?.getIdToken();

  Map<String, dynamic> decodedToken = JwtDecoder.decode(idTokenResult!);

  return decodedToken;
});

class Editor extends ConsumerStatefulWidget {
  final String? content;
  final String? childId;
  final StateProvider<dynamic>? provider;
  const Editor({
    super.key,
    this.provider,
    this.content,
    this.childId,
  });

  @override
  ConsumerState<Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<Editor> {
  // final _showPreview = StateProvider<bool>((ref) => false);
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();

  final picker = ImagePicker();
  @override
  Widget build(BuildContext context) {
    if (widget.content != null && widget.content!.isNotEmpty) {
      try {
        _controller.text = utf8.decode(base64.decode(widget.content ?? ''));
      } catch (e) {
        debugPrint('error: $e');
      }
    }
    //
    var test = md.markdownToHtml(_controller.text);
    return DefaultTabController(
      initialIndex: 0,
      length: 2,
      child: Scaffold(
          appBar: AppBar(
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    FilledButton(
                      child: const Text('Save'),
                      onPressed: () {
                        if (widget.content != null) {
                          ref.read(firestoreProvider).setData(
                            path: 'manuals/${widget.childId}',
                            model: {
                              'htmlContent': test,
                              'content': _controller.text,
                              'base64Content':
                                  base64.encode(utf8.encode(_controller.text)),
                              'revisionDate': DateTime.now(),
                              'editedBy':
                                  ref.watch(customClaimsProvider).value['rank'],
                              'editorName':
                                  ref.watch(customClaimsProvider).value['name'],
                            },
                          );
                          if (kDebugMode) {
                            print(
                              {
                                // 'htmlContent': test,
                                // 'content': _controller.text,
                                // 'base64Content':
                                // base64.encode(utf8.encode(_controller.text)),
                                'revisionDate': DateTime.now(),
                                'editedBy': ref
                                    .watch(customClaimsProvider)
                                    .value['rank'],
                                'editorName': ref
                                    .watch(customClaimsProvider)
                                    .value['name'],
                              },
                            );
                          }
                          context.pop();
                        } else {
                          ref
                                  .read(widget.provider!.notifier)
                                  .state['htmlContent'] =
                              md.markdownToHtml(_controller.text);
                          ref.read(widget.provider!.notifier).state['content'] =
                              _controller.text;

                          ref
                                  .read(widget.provider!.notifier)
                                  .state['base64Content'] =
                              base64.encode(utf8.encode(_controller.text));

                          context.pop();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
            bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: ['Write', 'Preview']
                    .map((e) => Tab(
                          text: e,
                        ))
                    .toList()),
          ),
          body: TabBarView(children: [
            write(context),
            preview(context),
          ])),
    );
  }

  write(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 1.0,
        // toolbarOpacity = 1.0,
        //bottomOpacity = 1.0,
        toolbarHeight: 34,
        // leadingWidth,
        automaticallyImplyLeading: false,
        title: KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: (event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.tab) {
              final text = _controller.text;

              final newText =
                  '${text.substring(0, _controller.selection.start)}\t${text.substring(_controller.selection.end)}';
              _controller.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(
                    offset: _controller.selection.start + 1),
              );
              _focusNode.requestFocus();

              return;
            }
            if (event.logicalKey == LogicalKeyboardKey.control &&
                event.logicalKey == LogicalKeyboardKey.keyB) {
              _applyTextStyle('**', '**');
              _focusNode.requestFocus();
              return;
            }
            if (event.logicalKey == LogicalKeyboardKey.control &&
                event.logicalKey == LogicalKeyboardKey.keyI) {
              _applyTextStyle('_', '_');
              _focusNode.requestFocus();
              return;
            }
          },
          child: ListTile(
            title: SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.title),
                    tooltip: "Heading",
                    onPressed: () {
                      _applyTextStyle('# ', '# ');
                      _focusNode.requestFocus();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_bold),
                    tooltip: "Bold",
                    onPressed: () {
                      _applyTextStyle('**', '**');
                      _focusNode.requestFocus();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_italic),
                    tooltip: 'Italic',
                    onPressed: () {
                      _applyTextStyle('_', '_');
                      _focusNode.requestFocus();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_list_bulleted),
                    tooltip: 'Bullet',
                    onPressed: () {
                      _applyBulletStyle();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_list_numbered),
                    tooltip: 'Numbered List',
                    onPressed: () {
                      _addNumberedItem();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.link),
                    tooltip: 'Insert Image Url',
                    onPressed: () {
                      _applyTextStyle('![', '](Enter image URL here)');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_upload),
                    tooltip: 'Upload Image',
                    onPressed: () {
                      gallery(
                        context,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_line_spacing),
                    tooltip: 'Line & paragraph spacing',
                    onPressed: () {
                      _applyTextStyle('```line \n 1', '\n```');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.table_view),
                    tooltip: 'Table',
                    onPressed: () {
                      _applyTextStyle(
                          '| Heading         | Heading          | \n',
                          '| :----------- | :--------------: |\n'
                              '| text | Text  |\n'
                              '| More text    | more text   |');
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.html),
                    tooltip: 'HTML',
                    onPressed: () {
                      _applyTextStyle(
                          ' ```html \n <h1>html tag</h1> \n``` ', '');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                minLines: 8,
                controller: _controller,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Enter your text here...',
                  border: OutlineInputBorder(),
                ),
                // onChanged: (value) {
                //   _controller.text = value;
              ),
            ],
          ),
        ),
      ),
    );
  }

  preview(context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Preview(content: _controller),
        ),
      ],
    );
  }

  int _lineNumber = 1;
  int _lastEnterPressTime = 0;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        RawKeyboard.instance.addListener(_handleKeyEvent);
      } else {
        RawKeyboard.instance.removeListener(_handleKeyEvent);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    RawKeyboard.instance.removeListener(_handleKeyEvent);
    super.dispose();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final int currentTime = DateTime.now().millisecondsSinceEpoch;
        if (currentTime - _lastEnterPressTime < 300) {
          // Double tap detected
          _stopNumberedList();
        } else {
          // Single tap detected
          _addNumberedItem();
        }
        _lastEnterPressTime = currentTime;
      }
    }
  }

  void _stopNumberedList() {
    _controller.text += '\n';
    _lineNumber = 1;
  }

  void _addNumberedItem() {
    String currentText = _controller.text;
    if (currentText.isNotEmpty && !currentText.endsWith('\n')) {
      currentText += '\n';
    }
    _controller.text = '$currentText$_lineNumber. ';
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    _lineNumber++;
  }

  void _applyTextStyle(String prefix, String suffix) {
    final int selectionStart = _controller.selection.start;
    final int selectionEnd = _controller.selection.end;
    final String textBeforeSelection =
        _controller.text.substring(0, selectionStart);
    final String selectedText =
        _controller.text.substring(selectionStart, selectionEnd);
    final String textAfterSelection = _controller.text.substring(selectionEnd);

    final List<String> lines = selectedText.split('\n');
    final List<String> modifiedLines = [];

    for (int i = 0; i < lines.length; i++) {
      modifiedLines.add('$prefix${lines[i]}$suffix');
    }

    final String modifiedText = modifiedLines.join('\n');

    final String newText =
        '$textBeforeSelection$modifiedText$textAfterSelection';

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: selectionStart,
        extentOffset: selectionStart + modifiedText.length,
      ),
    );
  }

  void _applyBulletStyle() {
    final String selectedText =
        _controller.selection.textInside(_controller.text);
    if (selectedText.isNotEmpty) {
      final List<String> lines = selectedText.split('\n');
      final List<String> modifiedLines = [];

      for (int i = 0; i < lines.length; i++) {
        if (lines[i].trim().isNotEmpty) {
          modifiedLines.add('\n- ${lines[i]}');
        }
      }

      final String modifiedText = modifiedLines.join('');
      _replaceSelectedText(modifiedText);
    }
  }

  void _replaceSelectedText(String newText) {
    final int selectionStart = _controller.selection.start;
    final int selectionEnd = _controller.selection.end;
    final String textBeforeSelection =
        _controller.text.substring(0, selectionStart);
    final String textAfterSelection = _controller.text.substring(selectionEnd);

    _controller.value = TextEditingValue(
      text: '$textBeforeSelection$newText$textAfterSelection',
      selection:
          TextSelection.collapsed(offset: selectionStart + newText.length),
    );
  }

  bool isUploading = false;
  void gallery(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          // ignore: sized_box_for_whitespace
          content: Container(
            width: MediaQuery.of(context).size.width * 0.5,
            height: MediaQuery.of(context).size.height * 0.5,
            child: DefaultTabController(
              initialIndex: 0,
              length: 2,
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('Gallery'),
                  bottom: const TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(text: 'Gallery'),
                      Tab(text: 'Device'),
                    ],
                  ),
                ),
                body: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.blue[100],
                      child: StreamBuilder(
                        stream: FirebaseFirestore.instance
                            .collection('gallery')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Text('Error: ${snapshot.error}');
                          }
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasData) {
                            final data = snapshot.requireData;
                            return GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 5,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 0.75,
                              ),
                              itemCount: data.size,
                              itemBuilder: (context, index) {
                                final url = data.docs[index].data();
                                return GestureDetector(
                                  onTap: () {
                                    _insertImageUrl(url['imageUrl']);
                                  },
                                  child: Card(
                                    borderOnForeground: false,
                                    child: Image.network(
                                      url['imageUrl'],
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                );
                              },
                            );
                          } else {
                            return Container();
                          }
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(247, 226, 226, 221),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: InkWell(
                        onTap: () {
                          _uploadImage();
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isUploading)
                              const CircularProgressIndicator()
                            else
                              Image.asset(
                                '../../../assets/images/upload.webp',
                                fit: BoxFit.contain,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  openPhotos() {
    return FirebaseFirestore.instance.collection('gallery').snapshots();
  }

  Future<void> _uploadImage() async {
    if (kIsWeb) {
      final FilePickerResult? picker = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (picker != null && picker.files.isNotEmpty) {
        Uint8List bytes = picker.files.single.bytes!;
        String fileName = DateTime.now().millisecondsSinceEpoch.toString() +
            picker.files.single.name.toString().replaceAll(' ', '_');

        FirebaseStorage storage =
            FirebaseStorage.instanceFor(bucket: 'gs://testcdn');
        Reference ref = storage.ref().child('images/$fileName');
        ref.putData(bytes, SettableMetadata(contentType: 'image/png'));

        String downloadUrl =
            'https://storage.googleapis.com/testcdn/images/$fileName';

        FirebaseFirestore.instance
            .collection('gallery')
            .add({'imageUrl': downloadUrl});

        if (kDebugMode) {
          print("Download URL: $downloadUrl");
        }

        _insertImageUrl(downloadUrl);
      } else {
        if (kDebugMode) {
          print('No image selected.');
        }
        return;
      }
    } else {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickMedia();

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        String fileName = DateTime.now().millisecondsSinceEpoch.toString() +
            pickedFile.name.toString().replaceAll(' ', '_');

        FirebaseStorage storage =
            FirebaseStorage.instanceFor(bucket: 'gs://testcdn');
        Reference ref = storage.ref().child('images/$fileName');
        ref.putFile(imageFile);

        String downloadUrl =
            'https://storage.googleapis.com/testcdn/images/$fileName';

        if (kDebugMode) {
          print("Download URL: $downloadUrl");
        }
        _insertImageUrl(downloadUrl);
      } else {
        if (kDebugMode) {
          print('No image selected.');
        }
        return;
      }
    }
  }

  void _insertImageUrl(imageString) {
    final imageMarkdown = '![Alt text]($imageString)';
    _replaceSelectedText(imageMarkdown);
  }
}

class Preview extends StatelessWidget {
  final dynamic content;
  const Preview({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: content.text,
      selectable: true,
      softLineBreak: true,
      onTapLink: (text, url, title) {
        if (url != null) {
          launchUrl(Uri.parse(url));
        }
      },
      imageBuilder: (uri, title, alt) {
        return Image.network(uri.toString());
      },
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [md.EmojiSyntax(), ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
      ),
      builders: {
        'code': MermaidElementBuilder(),
      },
    );
    // return MarkdownBody(data: content.text);
  }
}

class MermaidElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(BuildContext context, md.Element element,
      TextStyle? preferredStyle, TextStyle? parentStyle) {
    if (element.tag == 'code' &&
        element.attributes['class'] == 'language-mermaid') {
      return MermaidWidget(
        text: element.textContent,
      );
    } else if (element.tag == 'code' &&
        element.attributes['class'] == 'language-line') {
      var space = double.tryParse(element.textContent);
      if (space == null || !space.isFinite) {
        space = element.textContent.length.toDouble();
      }

      // print(' Hieght :${space}');

      return SizedBox(
        height: 16 * space,
      );
    } else if (element.tag == 'code' &&
        element.attributes['class'] == 'language-mermaid') {
      return MermaidWidget(
        text: element.textContent,
      );
    } else if (element.tag == 'code' &&
        element.attributes['class'] == 'language-html') {
      return Html(
        data: element.textContent,
      );
    }

    return Container();
  }
}

class MermaidWidget extends StatelessWidget {
  final String text;

  const MermaidWidget({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    late final WebViewController controller;

    String htmlString = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="initial-scale=1, maximum-scale=1, user-scalable=no, width=device-width, viewport-fit=cover">
      </head>
      <body>
      
        <pre class="mermaid">$text</pre>
        <script type="module">
            import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
            mermaid.initialize({ startOnLoad: true });
        </script>
      </body>
      </html>
      ''';
    controller = WebViewController()..loadHtmlString(htmlString);

    if (kIsWeb) {
      // WebViewPlatform.instance = WebWebViewPlatform();
    } else {
      // controller.setNavigationDelegate(
      //     NavigationDelegate(onNavigationRequest: (request) {
      //   return NavigationDecision.prevent;
      // }, onPageFinished: (x) async {
      //   var x = await controller.runJavaScriptReturningResult(
      //       "document.documentElement.scrollHeight");
      //   double? y = double.tryParse(x.toString());
      //   debugPrint('parse : $y');
      // }));
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    }
    return Center(
        child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
              borderRadius: const BorderRadius.all(
                Radius.circular(12),
              ),
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height / 2,
              width: MediaQuery.of(context).size.width / 4,
              child: Center(
                child: WebViewWidget(
                  controller: controller,
                ),
              ),
            )));
  }
}
