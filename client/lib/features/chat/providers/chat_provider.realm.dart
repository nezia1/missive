// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_provider.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

// ignore_for_file: type=lint
class PlaintextMessage extends _PlaintextMessage
    with RealmEntity, RealmObjectBase, RealmObject {
  PlaintextMessage(
    String id,
    String content,
    bool own, {
    String? receiver,
    DateTime? sentAt,
  }) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'content', content);
    RealmObjectBase.set(this, 'own', own);
    RealmObjectBase.set(this, 'receiver', receiver);
    RealmObjectBase.set(this, 'sentAt', sentAt);
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
  DateTime? get sentAt =>
      RealmObjectBase.get<DateTime>(this, 'sentAt') as DateTime?;
  @override
  set sentAt(DateTime? value) => RealmObjectBase.set(this, 'sentAt', value);

  @override
  Stream<RealmObjectChanges<PlaintextMessage>> get changes =>
      RealmObjectBase.getChanges<PlaintextMessage>(this);

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
      } =>
        PlaintextMessage(
          fromEJson(id),
          fromEJson(content),
          fromEJson(own),
          receiver: fromEJson(receiver),
          sentAt: fromEJson(sentAt),
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
      SchemaProperty('sentAt', RealmPropertyType.timestamp, optional: true),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class User extends _User with RealmEntity, RealmObjectBase, RealmObject {
  User(
    String name, {
    Iterable<PlaintextMessage> messages = const [],
  }) {
    RealmObjectBase.set(this, 'name', name);
    RealmObjectBase.set<RealmList<PlaintextMessage>>(
        this, 'messages', RealmList<PlaintextMessage>(messages));
  }

  User._();

  @override
  String get name => RealmObjectBase.get<String>(this, 'name') as String;
  @override
  set name(String value) => RealmObjectBase.set(this, 'name', value);

  @override
  RealmList<PlaintextMessage> get messages =>
      RealmObjectBase.get<PlaintextMessage>(this, 'messages')
          as RealmList<PlaintextMessage>;
  @override
  set messages(covariant RealmList<PlaintextMessage> value) =>
      throw RealmUnsupportedSetError();

  @override
  Stream<RealmObjectChanges<User>> get changes =>
      RealmObjectBase.getChanges<User>(this);

  @override
  User freeze() => RealmObjectBase.freezeObject<User>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'name': name.toEJson(),
      'messages': messages.toEJson(),
    };
  }

  static EJsonValue _toEJson(User value) => value.toEJson();
  static User _fromEJson(EJsonValue ejson) {
    return switch (ejson) {
      {
        'name': EJsonValue name,
        'messages': EJsonValue messages,
      } =>
        User(
          fromEJson(name),
          messages: fromEJson(messages),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(User._);
    register(_toEJson, _fromEJson);
    return SchemaObject(ObjectType.realmObject, User, 'User', [
      SchemaProperty('name', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('messages', RealmPropertyType.object,
          linkTarget: 'PlaintextMessage',
          collectionType: RealmCollectionType.list),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}
