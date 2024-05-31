/// Commands/Op Codes supported by various Bluetooth Charachteristics
library;

/// List of opCodes supported by DataSyncCharacteristics.transfer.characteristic
enum DataReadyOps {
  start(0),
  retry(1),
  ack(2),
  reset(3),
  skip(4),
  ;

  const DataReadyOps(this.opCode);

  final int opCode;
}
