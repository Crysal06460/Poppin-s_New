import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

const Color _primaryBlue = Color(0xFF3D9DF2);
const Color _lightBlue = Color(0xFFDFE9F2);

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}

/// Chat IA limité (5 questions/jour) pour les questions sur la mensualisation,
/// les congés payés, les indemnités et les démarches Pajemploi.
class CalculsChatScreen extends StatefulWidget {
  const CalculsChatScreen({super.key});

  @override
  State<CalculsChatScreen> createState() => _CalculsChatScreenState();
}

class _CalculsChatScreenState extends State<CalculsChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text:
          "Bonjour ! Posez-moi vos questions sur la mensualisation, les congés payés, les indemnités ou Pajemploi. "
          "Vous disposez de 5 questions par jour.",
      isUser: false,
    ),
  ];
  bool _isSending = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _sendQuestion() async {
    final question = _inputController.text.trim();
    if (question.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));
      _isSending = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final HttpsCallable callable =
          FirebaseFunctions.instanceFor(region: 'europe-west1')
              .httpsCallable('askCalculAssistant');

      final result = await callable.call({'question': question});
      final response = result.data['response'] as String?;

      setState(() {
        _messages.add(
          _ChatMessage(
            text: response ?? "Désolé, je n'ai pas pu générer de réponse.",
            isUser: false,
          ),
        );
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _messages.add(
          _ChatMessage(
            text: e.message ??
                "Une erreur est survenue, veuillez réessayer plus tard.",
            isUser: false,
          ),
        );
      });
    } catch (_) {
      setState(() {
        _messages.add(
          const _ChatMessage(
            text: "Une erreur est survenue, veuillez réessayer plus tard.",
            isUser: false,
          ),
        );
      });
    } finally {
      setState(() {
        _isSending = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "IA Poppin's",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return Align(
                    alignment: message.isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      decoration: BoxDecoration(
                        color: message.isUser ? _primaryBlue : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color:
                              message.isUser ? Colors.white : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isSending)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5EAF0))),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 13,
                          color: Colors.black.withOpacity(0.45),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            "L'IA peut se tromper : vérifiez les informations importantes.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.black.withOpacity(0.45),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          enabled: !_isSending,
                          decoration: InputDecoration(
                            hintText: 'Votre question...',
                            filled: true,
                            fillColor: _lightBlue.withOpacity(0.4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _sendQuestion(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isSending ? null : _sendQuestion,
                        icon: const Icon(Icons.send, color: _primaryBlue),
                      ),
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
}
