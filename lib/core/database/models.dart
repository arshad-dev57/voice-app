class AppUser {
  final String id;
  final String name;
  final String email;
  final bool isAuthenticated;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.isAuthenticated,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'is_authenticated': isAuthenticated ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      isAuthenticated: map['is_authenticated'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class Contact {
  final String id;
  final String name;
  final String phoneNumber;
  final String? email;
  final String? photoUri;
  final DateTime createdAt;

  Contact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.photoUri,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'email': email,
      'photo_uri': photoUri,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'],
      name: map['name'],
      phoneNumber: map['phone_number'],
      email: map['email'],
      photoUri: map['photo_uri'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class Message {
  final String id;
  final String conversationId;
  final String senderPhone;
  final String receiverPhone;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderPhone,
    required this.receiverPhone,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_phone': senderPhone,
      'receiver_phone': receiverPhone,
      'content': content,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      conversationId: map['conversation_id'],
      senderPhone: map['sender_phone'],
      receiverPhone: map['receiver_phone'],
      content: map['content'],
      isRead: map['is_read'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class Conversation {
  final String id;
  final String contactName;
  final String contactPhone;
  final String lastMessage;
  final DateTime lastMessageTime;

  Conversation({
    required this.id,
    required this.contactName,
    required this.contactPhone,
    required this.lastMessage,
    required this.lastMessageTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime.toIso8601String(),
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'],
      contactName: map['contact_name'],
      contactPhone: map['contact_phone'],
      lastMessage: map['last_message'],
      lastMessageTime: DateTime.parse(map['last_message_time']),
    );
  }
}

class Reminder {
  final String id;
  final String title;
  final DateTime dateTime;
  final String category; // medicine, meeting, generic
  final String repeatType; // none, daily, weekly
  final bool isCompleted;
  final DateTime createdAt;

  Reminder({
    required this.id,
    required this.title,
    required this.dateTime,
    required this.category,
    required this.repeatType,
    required this.isCompleted,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date_time': dateTime.toIso8601String(),
      'category': category,
      'repeat_type': repeatType,
      'is_completed': isCompleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'],
      title: map['title'],
      dateTime: DateTime.parse(map['date_time']),
      category: map['category'],
      repeatType: map['repeat_type'],
      isCompleted: map['is_completed'] == 1,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class Alarm {
  final String id;
  final String time; // e.g. "07:30"
  final String label;
  final bool isEnabled;
  final String repeatDays; // comma separated: e.g. "Mon,Tue,Wed"
  final DateTime createdAt;

  Alarm({
    required this.id,
    required this.time,
    required this.label,
    required this.isEnabled,
    required this.repeatDays,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'time': time,
      'label': label,
      'is_enabled': isEnabled ? 1 : 0,
      'repeat_days': repeatDays,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Alarm.fromMap(Map<String, dynamic> map) {
    return Alarm(
      id: map['id'],
      time: map['time'],
      label: map['label'],
      isEnabled: map['is_enabled'] == 1,
      repeatDays: map['repeat_days'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime dateTime;
  final int durationMinutes;
  final DateTime createdAt;

  CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.dateTime,
    required this.durationMinutes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date_time': dateTime.toIso8601String(),
      'duration_minutes': durationMinutes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      dateTime: DateTime.parse(map['date_time']),
      durationMinutes: map['duration_minutes'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class AssistantHistory {
  final String id;
  final String userQuery;
  final String assistantResponse;
  final String intent;
  final DateTime timestamp;

  AssistantHistory({
    required this.id,
    required this.userQuery,
    required this.assistantResponse,
    required this.intent,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_query': userQuery,
      'assistant_response': assistantResponse,
      'intent': intent,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AssistantHistory.fromMap(Map<String, dynamic> map) {
    return AssistantHistory(
      id: map['id'],
      userQuery: map['user_query'],
      assistantResponse: map['assistant_response'],
      intent: map['intent'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
