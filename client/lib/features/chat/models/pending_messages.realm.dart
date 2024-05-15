// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_messages.dart';

// **************************************************************************
// RealmObjectGenerator
// **************************************************************************

// ignore_for_file: type=lint
class PendingMessages extends _PendingMessages
    with RealmEntity, RealmObjectBase, RealmObject {
  PendingMessages(
    String id, {
    Iterable<PendingMessage> messages = const [],
  }) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set<RealmList<PendingMessage>>(
        this, 'messages', RealmList<PendingMessage>(messages));
  }

  PendingMessages._();

  @override
  String get id => RealmObjectBase.get<String>(this, 'id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, 'id', value);

  @override
  RealmList<PendingMessage> get messages =>
      RealmObjectBase.get<PendingMessage>(this, 'messages')
          as RealmList<PendingMessage>;
  @override
  set messages(covariant RealmList<PendingMessage> value) =>
      throw RealmUnsupportedSetError();

  @override
  Stream<RealmObjectChanges<PendingMessages>> get changes =>
      RealmObjectBase.getChanges<PendingMessages>(this);

  @override
  Stream<RealmObjectChanges<PendingMessages>> changesFor(
          [List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<PendingMessages>(this, keyPaths);

  @override
  PendingMessages freeze() =>
      RealmObjectBase.freezeObject<PendingMessages>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'messages': messages.toEJson(),
    };
  }

  static EJsonValue _toEJson(PendingMessages value) => value.toEJson();
  static PendingMessages _fromEJson(EJsonValue ejson) {
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'messages': EJsonValue messages,
      } =>
        PendingMessages(
          fromEJson(id),
          messages: fromEJson(messages),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(PendingMessages._);
    register(_toEJson, _fromEJson);
    return SchemaObject(
        ObjectType.realmObject, PendingMessages, 'PendingMessages', [
      SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('messages', RealmPropertyType.object,
          linkTarget: 'PendingMessage',
          collectionType: RealmCollectionType.list),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}

class PendingMessage extends _PendingMessage
    with RealmEntity, RealmObjectBase, RealmObject {
  PendingMessage(
    String id,
    String ciphertextMessage,
    String receiver,
  ) {
    RealmObjectBase.set(this, 'id', id);
    RealmObjectBase.set(this, 'ciphertextMessage', ciphertextMessage);
    RealmObjectBase.set(this, 'receiver', receiver);
  }

  PendingMessage._();

  @override
  String get id => RealmObjectBase.get<String>(this, 'id') as String;
  @override
  set id(String value) => RealmObjectBase.set(this, 'id', value);

  @override
  String get ciphertextMessage =>
      RealmObjectBase.get<String>(this, 'ciphertextMessage') as String;
  @override
  set ciphertextMessage(String value) =>
      RealmObjectBase.set(this, 'ciphertextMessage', value);

  @override
  String get receiver =>
      RealmObjectBase.get<String>(this, 'receiver') as String;
  @override
  set receiver(String value) => RealmObjectBase.set(this, 'receiver', value);

  @override
  Stream<RealmObjectChanges<PendingMessage>> get changes =>
      RealmObjectBase.getChanges<PendingMessage>(this);

  @override
  Stream<RealmObjectChanges<PendingMessage>> changesFor(
          [List<String>? keyPaths]) =>
      RealmObjectBase.getChangesFor<PendingMessage>(this, keyPaths);

  @override
  PendingMessage freeze() => RealmObjectBase.freezeObject<PendingMessage>(this);

  EJsonValue toEJson() {
    return <String, dynamic>{
      'id': id.toEJson(),
      'ciphertextMessage': ciphertextMessage.toEJson(),
      'receiver': receiver.toEJson(),
    };
  }

  static EJsonValue _toEJson(PendingMessage value) => value.toEJson();
  static PendingMessage _fromEJson(EJsonValue ejson) {
    return switch (ejson) {
      {
        'id': EJsonValue id,
        'ciphertextMessage': EJsonValue ciphertextMessage,
        'receiver': EJsonValue receiver,
      } =>
        PendingMessage(
          fromEJson(id),
          fromEJson(ciphertextMessage),
          fromEJson(receiver),
        ),
      _ => raiseInvalidEJson(ejson),
    };
  }

  static final schema = () {
    RealmObjectBase.registerFactory(PendingMessage._);
    register(_toEJson, _fromEJson);
    return SchemaObject(
        ObjectType.realmObject, PendingMessage, 'PendingMessage', [
      SchemaProperty('id', RealmPropertyType.string, primaryKey: true),
      SchemaProperty('ciphertextMessage', RealmPropertyType.string),
      SchemaProperty('receiver', RealmPropertyType.string),
    ]);
  }();

  @override
  SchemaObject get objectSchema => RealmObjectBase.getSchema(this) ?? schema;
}
