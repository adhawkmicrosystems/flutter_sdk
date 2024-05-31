import 'package:equatable/equatable.dart';

class Characteristic extends Equatable {
  const Characteristic(this.uuid, this.serviceUuid);
  final String serviceUuid;
  final String uuid;

  @override
  List<Object?> get props => [serviceUuid, uuid];

  @override
  String toString() => 'Service: $serviceUuid, Characteristic: $uuid';
}

/// Bluetooth GATT characteristics for the AdHawk Service
enum AdhawkCharacteristics {
  command('7f694ea3-1d44-49c5-8ae3-10e64037741e'),
  eyetrackingStream('26760f11-42c7-4439-8743-53a052d7e127'),
  eventStream('ab2af9ff-f7c2-4b21-bf52-b24113fea0f2'),
  statusStream('ab2af9ff-f7c2-4b21-bf52-b24113fea0f3'),
  ;

  const AdhawkCharacteristics(this.uuid);

  final String uuid;
  static const String serviceUuid = '6557674b-211f-425f-9bce-7234da8e588d';

  Characteristic get characteristic => Characteristic(uuid, serviceUuid);
}

/// Bluetooth GATT characteristics for the Battery Service
/// These numbers are assigned by the Bluetooth Core Specification
enum BatteryCharacteristics {
  batteryLevel('00002a19-0000-1000-8000-00805f9b34fb'),
  ;

  const BatteryCharacteristics(this.uuid);

  final String uuid;
  static const String serviceUuid = '0000180f-0000-1000-8000-00805f9b34fb';

  Characteristic get characteristic => Characteristic(uuid, serviceUuid);
}

/// Bluetooth GATT characteristics for the Time Synch Service
enum TimeCharacteristics {
  setTime('00020001-32bc-0000-bcdb-572cee397487'),
  ;

  const TimeCharacteristics(this.uuid);

  final String uuid;
  static const String serviceUuid = '00020000-32bc-0000-bcdb-572cee397487';

  Characteristic get characteristic => Characteristic(uuid, serviceUuid);
}

/// Bluetooth GATT characteristics for the Data Synch Service
enum DataSyncCharacteristics {
  ready('00030001-32bc-0000-bcdb-572cee397487'),
  transfer('00030002-32bc-0000-bcdb-572cee397487'),
  integrity('00030003-32bc-0000-bcdb-572cee397487'),
  ;

  const DataSyncCharacteristics(this.uuid);

  final String uuid;
  static const String serviceUuid = '00030000-32bc-0000-bcdb-572cee397487';

  Characteristic get characteristic => Characteristic(uuid, serviceUuid);
}

/// Bluetooth GATT characteristics for the Logging Service
enum LoggingCharacteristics {
  control('00040001-32bc-0000-bcdb-572cee397487'),
  ;

  const LoggingCharacteristics(this.uuid);

  final String uuid;
  static const String serviceUuid = '00040000-32bc-0000-bcdb-572cee397487';

  Characteristic get characteristic => Characteristic(uuid, serviceUuid);
}

/// Bluetooth GATT characteristics for the Generic Access Service
/// These numbers are assigned by the Bluetooth Core Specification
enum GenericAccessCharacteristics {
  deviceName('00002a00-0000-1000-8000-00805f9b34fb'),
  appearance('00002a01-0000-1000-8000-00805f9b34fb'),
  peripheralConnectionParams('00002a04-0000-1000-8000-00805f9b34fb'),
  ;

  const GenericAccessCharacteristics(this.uuid);

  final String uuid;
  static const String serviceUuid = '00001800-0000-1000-8000-00805f9b34fb';

  Characteristic get characteristic => Characteristic(uuid, serviceUuid);
}

/// Bluetooth GATT characteristics for the Generic Attribute Service
/// These numbers are assigned by the Bluetooth Core Specification
enum GenericAttributeCharacteristics {
  serviceChanged('00002a05-0000-1000-8000-00805f9b34fb'),
  clientSupportedFeatures('00002a05-0000-1000-8000-00805f9b34fb'),
  databaseHash('00002b2a-0000-1000-8000-00805f9b34fb'),
  ;

  const GenericAttributeCharacteristics(this.uuid);

  final String uuid;
  static const String serviceUuid = '00001801-0000-1000-8000-00805f9b34fb';

  Characteristic get characteristic => Characteristic(uuid, serviceUuid);
}

// Bluetooth GATT characteristics for the Device Information Service
// These numbers are assigned by the Bluetooth Core Specification
enum DeviceInformationCharacteristics {
  modelNumber('00002a24-0000-1000-8000-00805f9b34fb'),
  manufacturerName('00002a29-0000-1000-8000-00805f9b34fb'),
  firmwareRevision('00002a26-0000-1000-8000-00805f9b34fb'),
  hardwareRevision('00002a27-0000-1000-8000-00805f9b34fb'),
  ;

  const DeviceInformationCharacteristics(this.uuid);

  final String uuid;
  static const String serviceUuid = '0000180a-0000-1000-8000-00805f9b34fb';

  Characteristic get characteristic => Characteristic(uuid, serviceUuid);
}
