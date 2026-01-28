class BeaconTarget {
  final String macAddress;
  final String locationName;

  const BeaconTarget({
    required this.macAddress,
    required this.locationName,
  });
}

const List<BeaconTarget> myBeaconList = [
  BeaconTarget(
    macAddress: "C8:1F:29:AE:C8:64",
    locationName: "Butterworth - Manufacturing",
  ),
];