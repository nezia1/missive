// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

// ignore_for_file: type=lint
class Conversation extends _Conversation
    with RealmEntity, RealmObjectBase, RealmObject {
  Conversation(
    String username, {
    Iterable<PlaintextMessage> messages = const [],
  }) {
    RealmObjectBase.set(this, 'username', username);
    RealmObjectBase.set<RealmList<PlaintextMessage>>(
        this, 'messages', RealmList<PlaintextMessage>(messages));
  }

  Conversation._();

  @override
  String get username =>
      RealmObjectBase.get<String>(this, 'username') as String;
  @override
  set username(String value) => RealmObjectBase.set(this, 'username', value);

  @override
  RealmList<PlaintextMessage> get messages =>
      RealmObjectBase.get<PlaintextMessage>(this, 'messages')
          as RealmList<PlaintextMessage>;
  @override
  set messages(covariant RealmList<PlaintextMessage> value) =>
      throw RealmUnsupportedSetError();

  @override
  Stream<RealmObjectChanges<Conversation>> get changes =>
      RealmObjectBase.getChanges<Conversation>(this);

  @override
  Stream<RealmObjectChanges<Conversation>> changesFor(
          [List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<Conversation>(this, keyPaths);

  @override
  Conversation freeze() => RealmObjectBase.freezeObject<Conversation>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'username': username.toEJson(),
      'messages': messages.toEJson(),
    };
  }

  static EJsonValue _toEJson(Conversation value) => value.toEJson();
  static Conversation _fromEJson(EJsonValue ejson) {
    return switch (ejson) {
      {
        'username': EJsonValue username,
        'messages': EJsonValue messages,
      } =>
        Conversation(
          fromEJson(username),
          messages: fromEJson(messages),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(Conversation._);
    register(_toEJson, _fromEJson);
    return SchemaObject(ObjectType.realmObject, Conversation, 'Conversation', [
      SchemaProperty('username', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('messages', RealmPropertyType.object,
          linkTarget: 'PlaintextMessage',
          collectionType: RealmCollectionType.list),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class PlaintextMessage extends _PlaintextMessage
    with RealmEntity, RealmObjectBase, RealmObject {
  PlaintextMessage(
    String id,
    String content,
    bool own,
    DateTime sentAt, {
    String? receiver,
    String? statusString,
  }) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'content', content);
    RealmObjectBase.set(this, 'own', own);
    RealmObjectBase.set(this, 'receiver', receiver);
    RealmObjectBase.set(this, 'sentAt', sentAt);
    RealmObjectBase.set(this, 'statusString', statusString);
  }

  PlaintextMessage._();

  @override
  String get id => RealmObjectBase.get<String>(this, 'id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, 'id', value);

  @override
  String get content => RealmObjectBase.get<String>(this, 'content') as String;
  @override
  set content(String value) => RealmObjectBase.set(this, 'content', value);

  @override
  bool get own => RealmObjectBase.get<bool>(this, 'own') as bool;
  @override
  set own(bool value) => RealmObjectBase.set(this, 'own', value);

  @override
  String? get receiver =>
      RealmObjectBase.get<String>(this, 'receiver') as String?;
  @override
  set receiver(String? value) => RealmObjectBase.set(this, 'receiver', value);

  @override
  DateTime get sentAt =>
      RealmObjectBase.get<DateTime>(this, 'sentAt') as DateTime;
  @override
  set sentAt(DateTime value) => RealmObjectBase.set(this, 'sentAt', value);

  @override
  String? get statusString =>
      RealmObjectBase.get<String>(this, 'statusString') as String?;
  @override
  set statusString(String? value) =>
      RealmObjectBase.set(this, 'statusString', value);

  @override
  Stream<RealmObjectChanges<PlaintextMessage>> get changes =>
      RealmObjectBase.getChanges<PlaintextMessage>(this);

  @override
  Stream<RealmObjectChanges<PlaintextMessage>> changesFor(
          [List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<PlaintextMessage>(this, keyPaths);

  @override
  PlaintextMessage freeze() =>
      RealmObjectBase.freezeObject<PlaintextMessage>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'content': content.toEJson(),
      'own': own.toEJson(),
      'receiver': receiver.toEJson(),
      'sentAt': sentAt.toEJson(),
      'statusString': statusString.toEJson(),
    };
  }

  static EJsonValue _toEJson(PlaintextMessage value) => value.toEJson();
  static PlaintextMessage _fromEJson(EJsonValue ejson) {
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'content': EJsonValue content,
        'own': EJsonValue own,
        'receiver': EJsonValue receiver,
        'sentAt': EJsonValue sentAt,
        'statusString': EJsonValue statusString,
      } =>
        PlaintextMessage(
          fromEJson(id),
          fromEJson(content),
          fromEJson(own),
          fromEJson(sentAt),
          receiver: fromEJson(receiver),
          statusString: fromEJson(statusString),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(PlaintextMessage._);
    register(_toEJson, _fromEJson);
    return SchemaObject(
        ObjectType.realmObject, PlaintextMessage, 'PlaintextMessage', [
      SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('content', RealmPropertyType.string),
      SchemaProperty('own', RealmPropertyType.bool),
      SchemaProperty('receiver', RealmPropertyType.string, optional: true),
      SchemaProperty('sentAt', RealmPropertyType.timestamp),
      SchemaProperty('statusString', RealmPropertyType.string, optional: true),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}
