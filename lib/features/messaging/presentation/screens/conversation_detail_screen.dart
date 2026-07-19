import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/models.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../theme/app_theme.dart';

class ConversationDetailScreen extends ConsumerStatefulWidget {
  final String contactName;
  final String phoneNumber;

  const ConversationDetailScreen({
    super.key,
    required this.contactName,
    required this.phoneNumber,
  });

  @override
  ConsumerState<ConversationDetailScreen> createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState
    extends ConsumerState<ConversationDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isDictating = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final repo = ref.read(localRepositoryProvider);
    final list = await repo.getMessagesForConversation(
      'conv_${widget.contactName}',
    );
    setState(() {
      _messages = list;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final repo = ref.read(localRepositoryProvider);
    final msg = Message(
      id: const Uuid().v4(),
      conversationId: 'conv_${widget.contactName}',
      senderPhone: 'user',
      receiverPhone: widget.phoneNumber,
      content: text,
      isRead: true,
      createdAt: DateTime.now(),
    );

    await repo.insertMessage(msg);
    _messageController.clear();
    _loadMessages();

    // Mock an automatic responsive message from the contact after 1.5 seconds
    Future.delayed(const Duration(seconds: 1500), () async {
      if (!mounted) return;
      final replyMsg = Message(
        id: const Uuid().v4(),
        conversationId: 'conv_${widget.contactName}',
        senderPhone: widget.phoneNumber,
        receiverPhone: 'user',
        content: 'Received. Thanks!',
        isRead: false,
        createdAt: DateTime.now(),
      );
      await repo.insertMessage(replyMsg);
      _loadMessages();
    });
  }

  // Speak the conversation aloud
  void _readAloud() {
    if (_messages.isEmpty) return;
    final latest = _messages.last;
    final speaker = latest.senderPhone == 'user' ? 'You' : widget.contactName;
    final speechText = 'Latest message from $speaker, says: ${latest.content}';

    ref.read(ttsServiceProvider).speak(speechText);
  }

  // Dictate text via microphone speech recognition
  Future<void> _startDictation() async {
    final speech = ref.read(speechServiceProvider);
    if (_isDictating) {
      await speech.stopListening();
      setState(() => _isDictating = false);
    } else {
      setState(() => _isDictating = true);
      await speech.startListening(
        onResult: (text) {
          setState(() {
            _messageController.text = text;
          });
        },
        onSoundLevelChanged: () {},
        onError: () {
          setState(() => _isDictating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to read voice input.')),
          );
        },
        onComplete: () {
          setState(() => _isDictating = false);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contactName),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded),
            tooltip: 'Read last message',
            onPressed: _readAloud,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppTheme.darkBg, const Color(0xFF141923)]
                : [AppTheme.lightBg, const Color(0xFFE6EDF5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Chat bubble list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? const Center(child: Text('No messages. Say hi!'))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg.senderPhone == 'user';
                        final time = DateFormat(
                          'hh:mm a',
                        ).format(msg.createdAt);

                        return Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isMe
                                    ? const Radius.circular(16)
                                    : const Radius.circular(0),
                                bottomRight: isMe
                                    ? const Radius.circular(0)
                                    : const Radius.circular(16),
                              ),
                              gradient: isMe
                                  ? AppTheme.primaryGradient
                                  : LinearGradient(
                                      colors: isDark
                                          ? [
                                              Colors.white.withValues(
                                                alpha: 0.08,
                                              ),
                                              Colors.white.withValues(
                                                alpha: 0.08,
                                              ),
                                            ]
                                          : [
                                              Colors.black.withValues(
                                                alpha: 0.04,
                                              ),
                                              Colors.black.withValues(
                                                alpha: 0.04,
                                              ),
                                            ],
                                    ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.content,
                                  style: TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white
                                              : Colors.black87),
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  time,
                                  style: TextStyle(
                                    color: isMe ? Colors.white60 : Colors.grey,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Message composition row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.01)
                  : Colors.black.withValues(alpha: 0.01),
              child: Row(
                children: [
                  // Microphone Dictation Toggle
                  IconButton(
                    icon: Icon(
                      _isDictating ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _isDictating ? AppTheme.error : AppTheme.primary,
                    ),
                    onPressed: _startDictation,
                  ),
                  const SizedBox(width: 8),

                  // Text input
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.03)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.04),
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: _isDictating
                              ? 'Dictating...'
                              : 'Type a message...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      color: AppTheme.primary,
                    ),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
