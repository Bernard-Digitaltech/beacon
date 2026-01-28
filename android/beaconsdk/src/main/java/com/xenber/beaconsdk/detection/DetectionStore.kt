package com.xenber.beaconsdk.detection

data class DetectionRecord(
    val mac: String,
    val location: String,
    val rssi: Int,
    val timestamp: Long
)

class DetectionStore {

    private val detections = mutableListOf<DetectionRecord>()

    fun store(record: DetectionRecord) {
        detections.add(record)
    }

    fun getAll(): List<DetectionRecord> = detections.toList()

    fun clear() {
        detections.clear()
    }
}
