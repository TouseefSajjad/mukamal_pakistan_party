import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mukammalpakistanparty/models/chat_models.dart';
import 'package:mukammalpakistanparty/ChatMessage/services/chat_service.dart';
import 'package:mukammalpakistanparty/screens/home/home_screen.dart';
import 'package:mukammalpakistanparty/screens/nav/main_nav_screen.dart';
import 'package:mukammalpakistanparty/search/filter/chatscreen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with WidgetsBindingObserver {
  final ChatService _service = ChatService();
  final TextEditingController _searchCtrl = TextEditingController();

  bool _checkingAccess = true;
  bool _accessGranted = false;

  List<ChatUser> _allMembers = [];
  List<ChatUser> _filtered = [];
  String _roleFilter = 'all';
  String _searchQuery = '';
  StreamSubscription? _memberSub;

  // keyed by otherUid
  Map<String, ChatRoom> _chatRooms = {};
  // NEW: keyed by otherUid → chatId (so tile can subscribe to unread stream)
  Map<String, String> _chatIds = {};
  StreamSubscription? _chatRoomSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final allowed = await _service.canUserChat();
    if (!mounted) return;
    setState(() {
      _checkingAccess = false;
      _accessGranted = allowed;
    });
    if (allowed) {
      _service.setOnline();
      _subscribeMembers();
      _subscribeChatRooms();
    }
  }

  void _subscribeMembers() {
    _memberSub = _service.approvedMembersStream().listen((members) {
      if (!mounted) return;
      setState(() {
        _allMembers = members;
        _applyFilters();
      });
    });
  }

  void _subscribeChatRooms() {
    _chatRoomSub = _service.myChatRoomsStream().listen((rooms) {
      if (!mounted) return;
      final map = <String, ChatRoom>{};
      final idMap = <String, String>{}; // NEW
      final myUid = FirebaseAuth.instance.currentUser!.uid;
      for (final r in rooms) {
        final other = r.participants.firstWhere(
              (p) => p != myUid,
          orElse: () => '',
        );
        if (other.isNotEmpty) {
          map[other] = r;
          idMap[other] = r.chatId; // NEW: store chatId
        }
      }
      setState(() {
        _chatRooms = map;
        _chatIds = idMap; // NEW
      });
    });
  }

  void _applyFilters() {
    _filtered = _allMembers.where((m) {
      final matchRole = _roleFilter == 'all' || m.role == _roleFilter;
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          m.displayName.toLowerCase().contains(q) ||
          m.email.toLowerCase().contains(q);
      return matchRole && matchSearch;
    }).toList();
  }

  void _onSearch(String v) {
    setState(() {
      _searchQuery = v;
      _applyFilters();
    });
  }

  void _onRoleFilter(String? v) {
    setState(() {
      _roleFilter = v ?? 'all';
      _applyFilters();
    });
  }

  Future<void> _openChat(ChatUser user) async {
    final chatId = await _service.getOrCreateChatRoom(user.uid);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: chatId, otherUser: user),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_accessGranted) return;
    if (state == AppLifecycleState.resumed) {
      _service.setOnline();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _service.setOffline();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _memberSub?.cancel();
    _chatRoomSub?.cancel();
    _searchCtrl.dispose();
    _service.setOffline();
    super.dispose();
  }

  // ─────────────────────────── BUILD ──────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) return const _LoadingScaffold();
    if (!_accessGranted) return const _AccessDeniedScaffold();

    return Scaffold(
      backgroundColor: const Color(0xFF2E7D32),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildRoleFilter(),
          Expanded(child: _buildMemberList()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF2E7D32),
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Members Chat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Text(
            'Mukammal Pakistan Party',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearch,
        style: const TextStyle(fontSize: 14, color: Colors.black54),
        decoration: InputDecoration(
          hintText: 'Search members by name or email...',
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: () {
              _searchCtrl.clear();
              _onSearch('');
            },
          )
              : null,
          filled: true,
          fillColor: const Color(0xFFF0F0F0),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
      child: Row(
        children: [
          _roleChip('all', 'All members'),
          const SizedBox(width: 8),
          _roleChip('admin', 'Admin'),
          const SizedBox(width: 8),
          _roleChip('member', 'Member'),
          const Spacer(),
          Text(
            '${_filtered.length} found',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _roleChip(String value, String label) {
    final selected = _roleFilter == value;
    return GestureDetector(
      onTap: () => _onRoleFilter(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color:
          selected ? const Color(0xFF1D9E75) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberList() {
    if (_allMembers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 52, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No approved members yet',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No members match "$_searchQuery"',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 72,
        color: Colors.black54,
      ),
      itemBuilder: (_, i) => _MemberTile(
        user: _filtered[i],
        chatRoom: _chatRooms[_filtered[i].uid],
        // NEW: pass chatId and service so tile can stream unread count
        chatId: _chatIds[_filtered[i].uid],
        chatService: _service,
        onTap: () => _openChat(_filtered[i]),
      ),
    );
  }
}

// ── Member tile ──────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final ChatUser user;
  final ChatRoom? chatRoom;
  final VoidCallback onTap;
  // NEW
  final String? chatId;
  final ChatService chatService;

  const _MemberTile({
    required this.user,
    required this.chatRoom,
    required this.onTap,
    required this.chatId,       // NEW
    required this.chatService,  // NEW
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: user.role == 'admin'
                      ? const Color(0xFFE1F5EE)
                      : const Color(0xFFE6F1FB),
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL == null
                      ? Text(
                    user.initials,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: user.role == 'admin'
                          ? const Color(0xFF0F6E56)
                          : const Color(0xFF185FA5),
                    ),
                  )
                      : null,
                ),
                if (user.isOnline)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                        border:
                        Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(width: 12),

            // Name + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w300,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chatRoom != null && chatRoom!.lastUpdated != null)
                        Text(
                          _formatTime(chatRoom!.lastUpdated!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: user.role == 'admin'
                              ? const Color(0xFFE1F5EE)
                              : const Color(0xFFE6F1FB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          user.role,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: user.role == 'admin'
                                ? const Color(0xFF0F6E56)
                                : const Color(0xFF185FA5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          chatRoom?.lastMessage.isNotEmpty == true
                              ? chatRoom!.lastMessage
                              : user.isOnline
                              ? 'Online'
                              : user.lastSeen != null
                              ? 'Last seen ${_formatTime(user.lastSeen!)}'
                              : user.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                            chatRoom?.lastMessage.isNotEmpty == true
                                ? Colors.black54
                                : user.isOnline
                                ? const Color(0xFF1D9E75)
                                : Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // ── NEW: unread badge ────────────────────────────
                      if (chatId != null)
                        StreamBuilder<int>(
                          stream: chatService.unreadCountStream(chatId!),
                          builder: (context, snapshot) {
                            final count = snapshot.data ?? 0;
                            if (count == 0) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D9E75),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Text(
                                count > 99 ? '99+' : '$count',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                      // ────────────────────────────────────────────────
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

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } else {
      return '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}';
    }
  }
}

// ── Loading scaffold ─────────────────────────────────────────────────────────

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF1D9E75)),
            SizedBox(height: 16),
            Text('Checking access...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ── Access denied scaffold ───────────────────────────────────────────────────

class _AccessDeniedScaffold extends StatelessWidget {
  const _AccessDeniedScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        foregroundColor: Colors.white,
        title: const Text('Members Chat'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFFDEDED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline,
                    size: 48, color: Color(0xFFD32F2F)),
              ),
              const SizedBox(height: 24),
              const Text(
                'Access Restricted',
                style:
                TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Only approved members can access the party chat. '
                    'Your membership application may still be pending or '
                    'chat access has not been enabled for your role.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MainNavScreen()),
                ),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1D9E75),
                  side: const BorderSide(color: Color(0xFF1D9E75)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}