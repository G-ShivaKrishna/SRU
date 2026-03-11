import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/student_ai_assistant_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  static const Color _ink = Color(0xFF12304C);
  static const Color _deepBlue = Color(0xFF173F67);
  static const Color _sky = Color(0xFF4C8FD9);
  static const Color _mist = Color(0xFFF4F8FC);
  static const Color _line = Color(0xFFD6E2EE);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final StudentAiAssistantService _assistant = StudentAiAssistantService();

  final List<_ChatMessage> _messages = [];
  bool _isThinking = false;

  static const List<String> _quickPrompts = [
    'Show my latest CIE marks',
    'How many backlogs do I have?',
    'Show my attendance percentage',
    'What is my CGPA?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      const _ChatMessage(
        text:
            'Hi, I am your academic assistant. Ask me for marks, CGPA, attendance, backlogs, or profile details.',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? preset]) async {
    if (_isThinking) {
      return;
    }

    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isThinking = true;
    });
    _controller.clear();
    _scrollToBottom();

    final answer = await _assistant.getAnswer(text);

    if (!mounted) {
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(
        text: answer.text,
        isUser: false,
        suggestions: answer.suggestions,
      ));
      _isThinking = false;
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: _mist,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Text(
          'AI Academic Assistant',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F2740), Color(0xFF1B4F80)],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEAF3FB), Color(0xFFF8FBFE)],
            ),
          ),
          child: Column(
            children: [
              _buildHeroHeader(isMobile),
              _buildQuickPrompts(isMobile),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 12 : 18,
                    10,
                    isMobile ? 12 : 18,
                    18,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildBubble(message, isMobile);
                  },
                ),
              ),
              if (_isThinking) _buildThinkingCard(isMobile),
              _buildComposer(isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(bool isMobile) {
    return Container(
      width: double.infinity,
      margin:
          EdgeInsets.fromLTRB(isMobile ? 12 : 18, 14, isMobile ? 12 : 18, 0),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF103150), Color(0xFF215C95)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A0F2740),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAssistantBadge(isMobile ? 52 : 60),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          color: Color(0xFFFFD66E), size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'Smart academic answers',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ask once. Get marks, CGPA, attendance, and backlog details instantly.',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This assistant reads your academic data and replies in a cleaner summary format so you do not need to open each page manually.',
                  style: GoogleFonts.manrope(
                    color: Colors.white.withOpacity(0.84),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts(bool isMobile) {
    return SizedBox(
      height: isMobile ? 152 : 164,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(
          isMobile ? 12 : 18,
          12,
          isMobile ? 12 : 18,
          8,
        ),
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final prompt = _quickPrompts[index];
          return _buildPromptCard(prompt, isMobile);
        },
      ),
    );
  }

  Widget _buildPromptCard(String prompt, bool isMobile) {
    final icon = _iconForPrompt(prompt);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _sendMessage(prompt),
      child: Container(
        width: isMobile ? 180 : 210,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F2740),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: isMobile ? 38 : 42,
              height: isMobile ? 38 : 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDBECFF), Color(0xFFB8D7FA)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _deepBlue, size: isMobile ? 20 : 22),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'Ask now',
                        style: GoogleFonts.manrope(
                          color: _sky,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.north_east_rounded,
                          size: 15, color: _sky),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(_ChatMessage message, bool isMobile) {
    final align =
        message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final mainAxis =
        message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start;
    final bubbleGradient = message.isUser
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF173F67), Color(0xFF2C6CA8)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF8FBFF)],
          );
    final textColor = message.isUser ? Colors.white : _ink;

    return Column(
      crossAxisAlignment: align,
      children: [
        Row(
          mainAxisAlignment: mainAxis,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isUser) ...[
              _buildAssistantBadge(38),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 7),
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 14 : 16,
                  12,
                  isMobile ? 14 : 16,
                  13,
                ),
                constraints: BoxConstraints(maxWidth: isMobile ? 320 : 560),
                decoration: BoxDecoration(
                  gradient: bubbleGradient,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(22),
                    topRight: const Radius.circular(22),
                    bottomLeft: Radius.circular(message.isUser ? 22 : 8),
                    bottomRight: Radius.circular(message.isUser ? 8 : 22),
                  ),
                  border: message.isUser ? null : Border.all(color: _line),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140F2740),
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          message.isUser
                              ? Icons.person_rounded
                              : Icons.smart_toy_rounded,
                          size: 16,
                          color: message.isUser
                              ? Colors.white.withOpacity(0.88)
                              : _deepBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          message.isUser ? 'You' : 'Assistant',
                          style: GoogleFonts.manrope(
                            color: message.isUser
                                ? Colors.white.withOpacity(0.88)
                                : _deepBlue,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message.text,
                      style: GoogleFonts.manrope(
                        color: textColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.52,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (message.isUser) ...[
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0ECF8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_rounded,
                    color: _deepBlue, size: 21),
              ),
            ],
          ],
        ),
        if (!message.isUser && message.suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: message.suggestions
                  .map((s) => InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _isThinking ? null : () => _sendMessage(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _line),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_iconForPrompt(s), size: 15, color: _sky),
                              const SizedBox(width: 7),
                              Text(
                                s,
                                style: GoogleFonts.manrope(
                                  color: _ink,
                                  fontSize: 11.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildThinkingCard(bool isMobile) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(isMobile ? 12 : 18, 0, isMobile ? 12 : 18, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE0A6)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE9B8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology_alt_rounded,
                color: Color(0xFF8B5A00), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Assistant is reading your academic data...',
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6E4B00),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(bool isMobile) {
    return Container(
      padding:
          EdgeInsets.fromLTRB(isMobile ? 12 : 18, 10, isMobile ? 12 : 18, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        border: const Border(top: BorderSide(color: Color(0xFFE3E8EF))),
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F2740),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.only(bottom: 2, left: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE0EEFD), Color(0xFFC9DFFD)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.forum_rounded, color: _deepBlue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_isThinking,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: GoogleFonts.manrope(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask about marks, CGPA, attendance...',
                  hintStyle: GoogleFonts.manrope(
                    color: const Color(0xFF7B91A8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF173F67), Color(0xFF2C6CA8)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: IconButton(
                onPressed: _isThinking ? null : _sendMessage,
                icon: const Icon(Icons.arrow_upward_rounded,
                    color: Colors.white, size: 22),
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantBadge(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE4A1), Color(0xFFFFC95D)],
        ),
        borderRadius: BorderRadius.circular(size * 0.34),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22C38A0E),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        Icons.smart_toy_rounded,
        color: _deepBlue,
        size: size * 0.52,
      ),
    );
  }

  IconData _iconForPrompt(String prompt) {
    final text = prompt.toLowerCase();
    if (text.contains('cgpa') || text.contains('gpa')) {
      return Icons.workspace_premium_rounded;
    }
    if (text.contains('attendance')) {
      return Icons.calendar_month_rounded;
    }
    if (text.contains('backlog') || text.contains('supply')) {
      return Icons.assignment_late_rounded;
    }
    if (text.contains('marks') || text.contains('cie')) {
      return Icons.bar_chart_rounded;
    }
    return Icons.chat_bubble_rounded;
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final List<String> suggestions;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.suggestions = const [],
  });
}
