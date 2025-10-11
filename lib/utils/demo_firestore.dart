import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/demo_mode_service.dart';

extension DemoScopedPayload on Map<String, dynamic> {
  Map<String, dynamic> withDemoStamp({
    String? structureId,
    bool force = false,
  }) {
    if (!force && !DemoModeService.instance.isDemo) {
      return this;
    }

    final Map<String, dynamic> stamped = Map<String, dynamic>.from(this);
    stamped['is_demo'] = true;
    stamped['tenant_id'] = 'DEMO';
    if (structureId != null && structureId.isNotEmpty) {
      stamped['structureId'] = structureId;
    } else if (!stamped.containsKey('structureId')) {
      stamped['structureId'] = 'demo';
    }
    return stamped;
  }
}

extension DemoCollectionWriter on CollectionReference<Map<String, dynamic>> {
  Future<DocumentReference<Map<String, dynamic>>> addWithDemo(
    Map<String, dynamic> data, {
    String? structureId,
    bool force = false,
  }) {
    return add(data.withDemoStamp(structureId: structureId, force: force));
  }
}

extension DemoDocumentWriter on DocumentReference<Map<String, dynamic>> {
  Future<void> setWithDemo(
    Map<String, dynamic> data, {
    SetOptions? options,
    String? structureId,
    bool force = false,
  }) {
    return set(
      data.withDemoStamp(structureId: structureId, force: force),
      options,
    );
  }

  Future<void> updateWithDemo(
    Map<String, dynamic> data, {
    String? structureId,
    bool force = false,
  }) {
    return update(
      data.withDemoStamp(structureId: structureId, force: force),
    );
  }
}
