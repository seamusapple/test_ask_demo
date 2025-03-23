import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:math';
import 'dart:math' as math;

class QuestionRecord {
  final int timestamp;
  final String question;
  final int messageIndex;

  QuestionRecord({
    required this.timestamp,
    required this.question,
    required this.messageIndex,
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    final availableVersion = await WebViewEnvironment.getAvailableVersion();
    assert(
      availableVersion != null,
      'Failed to find an installed WebView2 Runtime or non-stable Microsoft Edge installation.',
    );
  }

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(kDebugMode);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat with AI',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
      ),
      home: ChatPage(),
    );
  }
}

class ChatPage extends StatefulWidget {
  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  InAppWebViewController? webViewController;
  final List<QuestionRecord> _questionHistory = [];
  final List<GlobalKey> _messageKeys = [];
  final List<double> _messageHeights = [];

  @override
  void initState() {
    super.initState();
    // Initialize keys and heights for existing messages
    _messageKeys.addAll(
      List.generate(_messages.length, (index) => GlobalKey()),
    );
    _messageHeights.addAll(List.generate(_messages.length, (index) => 0.0));
  }

  String _getPlotlyHtml(String jsonData) {
    return '''
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
          <style>
            body { 
              margin: 0; 
              padding: 0; 
              display: flex;
              justify-content: center;
              align-items: center;
              height: 100vh;
              background-color: white;
            }
            #chart { 
              width: 100%; 
              height: 100%;
            }
          </style>
        </head>
        <body>
          <div id="chart"></div>
          <script>
            document.addEventListener('DOMContentLoaded', function() {
              const data = $jsonData;
              Plotly.newPlot('chart', data.data, data.layout, {
                displayModeBar: false,
                responsive: true
              }).then(function() {
                window.addEventListener('resize', function() {
                  Plotly.Plots.resize(document.getElementById('chart'));
                });
              });
            });
          </script>
        </body>
      </html>
    ''';
  }

  // Add a simple test fake response with a plot
  final List<String> _fakeResponses = [
    '''# Flutter Development Guide
**Welcome to Flutter!** Here's a quick overview of what you can do.

## Basic Widgets
- MaterialApp
- Scaffold
- Container
- Text

### Code Example
Here's a simple Flutter widget:

```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Text('Hello, Flutter!'),
    );
  }
}
```

> **Note**: Always remember to use `const` constructors when possible.
''',

    '''## Data Structures in Dart
Let's explore some common data structures:

1. Lists
2. Maps
3. Sets

### Example Implementation
```dart
void main() {
  // List example
  final List<int> numbers = [1, 2, 3, 4, 5];
  
  // Map example
  final Map<String, dynamic> user = {
    'name': 'John',
    'age': 30,
    'isActive': true,
  };
}
```

#### Task List
- [x] Learn basic Dart syntax
- [ ] Master Flutter widgets
- [ ] Build first app
''',

    '''# Markdown Features Demo
## Text Formatting
- *Italic text* for emphasis
- **Bold text** for strong emphasis
- ~~Strikethrough~~ for deleted text
- `inline code` for code snippets

## Tables
| Feature | Support |
|---------|---------|
| Tables | ✓ |
| Lists | ✓ |
| Code blocks | ✓ |

### Images
Here's the Flutter logo:
![Flutter Logo](https://storage.googleapis.com/cms-storage-bucket/6a07d8a62f4308d2b854.svg)
''',

    '''# Flutter State Management
## Popular Solutions

1. Provider
2. Riverpod
3. Bloc
4. GetX

### Example Code
```dart
class CounterProvider extends ChangeNotifier {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }
}
```

> **Best Practice**: Choose the state management solution that best fits your project's needs.
''',

    '''# Flutter UI Design Tips
## Material Design Components

### Buttons
- ElevatedButton
- TextButton
- OutlinedButton

### Example Usage
```dart
ElevatedButton(
  onPressed: () {},
  child: Text('Click Me'),
  style: ElevatedButton.styleFrom(
    primary: Colors.blue,
    onPrimary: Colors.white,
  ),
)
```

#### Design Checklist
- [x] Use consistent spacing
- [x] Follow material design guidelines
- [ ] Implement dark theme
- [ ] Add accessibility features
''',

    '''# Data Visualization Example
Here's a simple line chart:

<plot>
{
  "data": [
    {
      "type": "scatter",
      "mode": "lines+markers",
      "x": [1, 2, 3, 4, 5],
      "y": [2, 5, 3, 8, 4],
      "name": "Data Series 1"
    }
  ],
  "layout": {
    "title": "Simple Line Chart",
    "height": 300,
    "margin": { "t": 40, "b": 20, "l": 40, "r": 20 }
  }
}
</plot>

This chart shows a simple data series with line and markers.
''',
  ];

  void _sendMessage() {
    if (_controller.text.isEmpty) return;

    setState(() {
      // Store the question in history
      _questionHistory.add(
        QuestionRecord(
          timestamp: DateTime.now().millisecondsSinceEpoch,
          question: _controller.text,
          messageIndex: _messages.length,
        ),
      );

      // Add messages as before
      _messages.add({'sender': 'user', 'text': _controller.text});
      _messages.add({
        'sender': 'ai',
        'text': _fakeResponses[Random().nextInt(_fakeResponses.length)],
      });

      // Add two keys and heights for both messages
      _messageKeys.add(GlobalKey());
      _messageKeys.add(GlobalKey());
      _messageHeights.add(0.0);
      _messageHeights.add(0.0);
    });

    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToMessage(int index) {
    if (_scrollController.hasClients &&
        index >= 0 &&
        index < _messages.length) {
      double scrollPosition = 0;
      for (int i = 0; i < index; i++) {
        scrollPosition += _messageHeights[i];
      }

      final screenHeight = MediaQuery.of(context).size.height;
      scrollPosition =
          scrollPosition - (screenHeight / 2) + (_messageHeights[index] / 2);

      _scrollController.animateTo(
        math.max(0, scrollPosition),
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Chat with AI',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Builder(
              builder:
                  (context) => IconButton(
                    icon: Icon(Icons.history),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    tooltip: 'Question History',
                  ),
            ),
          ),
        ],
      ),
      endDrawer: _buildHistoryDrawer(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message['sender'] == 'user';

                // Keep height measurement logic
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (index < _messageKeys.length &&
                      _messageKeys[index].currentContext != null) {
                    final RenderBox box =
                        _messageKeys[index].currentContext!.findRenderObject()
                            as RenderBox;
                    _updateMessageHeight(index, box.size.height);
                  }
                });

                return Padding(
                  padding: EdgeInsets.only(
                    top: 8.0,
                    bottom: 8.0,
                    left: isUser ? 48.0 : 0,
                    right: isUser ? 0 : 48.0,
                  ),
                  child: Row(
                    mainAxisAlignment:
                        isUser
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) _buildAvatar(false),
                      if (!isUser) SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment:
                              isUser
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                          children: [
                            Container(
                              key: _messageKeys[index],
                              padding: EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color:
                                    isUser
                                        ? theme.colorScheme.primary.withOpacity(
                                          0.1,
                                        )
                                        : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(isUser ? 16 : 4),
                                  topRight: Radius.circular(isUser ? 4 : 16),
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _buildMessageContent(
                                message['text']!,
                                isUser,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(
                                top: 4.0,
                                left: 4.0,
                                right: 4.0,
                              ),
                              child: Text(
                                DateTime.now().toString().substring(11, 16),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isUser) SizedBox(width: 8),
                      if (isUser) _buildAvatar(true),
                    ],
                  ),
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isUser) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser ? Colors.blue[100] : Colors.grey[200],
        shape: BoxShape.circle,
      ),
      child: Icon(
        isUser ? Icons.person : Icons.android,
        size: 16,
        color: isUser ? Colors.blue[900] : Colors.grey[800],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: Offset(0, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24.0),
                ),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                  ),
                  onSubmitted: (text) {
                    if (text.isNotEmpty) _sendMessage();
                  },
                ),
              ),
            ),
            SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _sendMessage,
                icon: Icon(Icons.send, color: Colors.white, size: 20),
                padding: EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 48),
                SizedBox(height: 8),
                Text('Question History'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _questionHistory.length,
              itemBuilder: (context, index) {
                final record = _questionHistory[index];
                return ListTile(
                  title: Text(
                    record.question,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    DateTime.fromMillisecondsSinceEpoch(
                      record.timestamp,
                    ).toString().substring(0, 16),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    _scrollToMessage(record.messageIndex);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _updateMessageHeight(int index, double height) {
    if (_messageHeights[index] != height) {
      setState(() {
        _messageHeights[index] = height;
      });
    }
  }

  Widget _buildPlotly(String jsonData) {
    return Container(
      height: 300,
      margin: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InAppWebView(
        initialData: InAppWebViewInitialData(
          data: _getPlotlyHtml(jsonData),
          mimeType: 'text/html',
          encoding: 'UTF-8',
        ),
        onWebViewCreated: (controller) {
          webViewController = controller;
        },
        onReceivedError: (controller, request, error) {
          debugPrint('Plotly error: $error');
        },
      ),
    );
  }

  Widget _buildMessageContent(String content, bool isUser) {
    if (!isUser && content.contains('<plot>')) {
      final parts = content.split('<plot>');
      final widgets = <Widget>[];

      for (var i = 0; i < parts.length; i++) {
        if (parts[i].contains('</plot>')) {
          final plotParts = parts[i].split('</plot>');
          final jsonData = plotParts[0].trim();

          widgets.add(
            MarkdownWidget(
              data: (i > 0 ? parts[i - 1] : ''),
              shrinkWrap: true,
              config: MarkdownConfig(
                configs: [const PreConfig(language: 'dart')],
              ),
            ),
          );

          widgets.add(_buildPlotly(jsonData));

          if (plotParts.length > 1) {
            widgets.add(
              MarkdownWidget(
                data: plotParts[1],
                shrinkWrap: true,
                config: MarkdownConfig(
                  configs: [const PreConfig(language: 'dart')],
                ),
              ),
            );
          }
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widgets,
      );
    }

    return isUser
        ? Text(content, style: TextStyle(fontSize: 16))
        : MarkdownWidget(
          data: content,
          shrinkWrap: true,
          config: MarkdownConfig(
            configs: [
              const PreConfig(language: 'dart'),
              TableConfig(
                wrapper:
                    (table) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: table,
                    ),
              ),
            ],
          ),
        );
  }
}
